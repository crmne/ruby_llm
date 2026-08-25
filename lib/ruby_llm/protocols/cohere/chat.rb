# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Chat methods for the Cohere v2 API implementation
      module Chat
        module_function

        def completion_url
          'v2/chat'
        end

        # rubocop:disable-next Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)

          payload = {
            model: model.id,
            messages: format_messages(messages, citations: citations),
            stream: stream
          }

          add_optional_fields(payload, messages, temperature:, max_output_tokens:, citations:, schema:)
          add_tools(payload, tools, tool_prefs || {})
          add_thinking(payload, thinking)
          payload
        end

        def add_optional_fields(payload, messages, temperature:, max_output_tokens:, citations:, schema:)
          payload[:temperature] = temperature unless temperature.nil?
          payload[:max_tokens] = max_output_tokens unless max_output_tokens.nil?
          payload[:documents] = Media.format_documents(messages) if citations && Media.documents?(messages)
          payload[:response_format] = build_response_format(schema) if schema
        end

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'with_citations may have no effect.'
          )
        end

        def add_tools(payload, tools, tool_prefs)
          return if tools.empty?

          payload[:tools] = tools.values.map { |tool| Tools.function_for(tool) }
          tool_choice = Tools.build_tool_choice(tool_prefs[:choice])
          payload[:tool_choice] = tool_choice if tool_choice
        end

        # Cohere takes a bare JSON Schema under json_schema, with no name or
        # strict wrapper.
        def build_response_format(schema)
          normalized = RubyLLM::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')

          { type: 'json_object', json_schema: normalized }
        end

        # Reasoning is on by default for models that support it, so an
        # explicit disable is as meaningful as an explicit enable.
        def add_thinking(payload, thinking)
          return unless thinking&.enabled?
          return payload[:thinking] = { type: 'disabled' } if thinking.effort.to_s == 'none'

          payload[:thinking] = { type: 'enabled', token_budget: thinking.budget }.compact
        end

        def format_messages(messages, citations: false)
          messages.map { |msg| format_message(msg, citations: citations) }
        end

        def format_message(msg, citations: false)
          return Tools.format_tool_result(msg) if msg.tool_result?
          return format_assistant_message(msg) if msg.role == :assistant

          {
            role: msg.role.to_s,
            content: Media.format_content(msg.content, msg.attachments, citations: citations)
          }
        end

        # Cohere returns tool_plan alongside tool calls, and RubyLLM surfaces
        # it as thinking, but the newer models reject it on the way back in.
        # It is optional in a request, so the plan stays out of the history.
        def format_assistant_message(msg)
          message = { role: 'assistant' }
          content = Media.format_content(msg.content, msg.attachments)
          message[:content] = content unless content.empty?
          message[:tool_calls] = Tools.format_tool_calls(msg.tool_calls) if msg.tool_call?
          message
        end

        def parse_completion_body(data, raw:)
          message_data = data['message'] || {}
          blocks = Array(message_data['content'])
          content, offsets = extract_text(blocks)
          finish_reason = data['finish_reason']

          Message.new(
            role: :assistant,
            content: content,
            citations: parse_citations(message_data['citations'], offsets),
            thinking: Thinking.build(text: extract_thinking(blocks, message_data)),
            tool_calls: Tools.parse_tool_calls(message_data['tool_calls'], response: raw, finish_reason:),
            finish_reason: finish_reason,
            model: model&.id,
            raw: raw,
            **usage_tokens(data['usage'] || {})
          )
        end

        # Cohere reports what the model processed under tokens and what it
        # charges for under billed_units; the two differ because Cohere does
        # not bill its own preamble.
        def usage_tokens(usage)
          tokens = usage['tokens'] || {}
          billed = usage['billed_units'] || {}

          {
            input_tokens: tokens['input_tokens'] || billed['input_tokens'],
            output_tokens: tokens['output_tokens'] || billed['output_tokens'],
            cache_read_tokens: usage['cached_tokens']
          }
        end

        # Returns the joined text of the response along with the offset each
        # content block starts at, so citation spans resolve against the
        # content string RubyLLM exposes.
        def extract_text(blocks)
          text = +''
          offsets = {}

          blocks.each_with_index do |block, index|
            next unless block['type'] == 'text'

            offsets[index] = text.length
            text << block['text'].to_s
          end

          [text, offsets]
        end

        # The tool plan is the model's reasoning for a tool-calling turn, and
        # is the only reasoning Cohere returns when thinking blocks are absent.
        def extract_thinking(blocks, message_data)
          thoughts = blocks.select { |block| block['type'] == 'thinking' }
                           .map { |block| block['thinking'] }.join
          thoughts.empty? ? message_data['tool_plan'] : thoughts
        end

        def parse_citations(citations, offsets)
          Array(citations).map { |citation| parse_citation(citation, offsets) }
        end

        # Only citations of the response text carry offsets into #content.
        # Citations of the thinking blocks or the tool plan point into text
        # RubyLLM exposes elsewhere, so they keep their snippet without a span.
        def parse_citation(data, offsets = {})
          source = Array(data['sources']).first
          document = source_document(source)
          start_index, end_index = citation_span(data, offsets)

          Citation.new(
            url: citation_url(document),
            title: document['title'] || document['id'],
            cited_text: document['text'] || document['snippet'],
            text: data['text'],
            start_index: start_index,
            end_index: end_index,
            source_index: source_index(source)
          )
        end

        def citation_span(data, offsets)
          return [nil, nil] unless text_citation?(data)

          offset = offsets[data['content_index'] || 0]
          return [nil, nil] unless offset

          [data['start'] && (offset + data['start']), data['end'] && (offset + data['end'])]
        end

        def text_citation?(data)
          type = data['type']
          type.nil? || type == 'TEXT_CONTENT'
        end

        def source_document(source)
          return {} unless source

          source['document'] || source['tool_output'] || {}
        end

        def citation_url(document)
          url = document['url']
          url if url.is_a?(String) && url.match?(%r{\Ahttps?://})
        end

        # Documents RubyLLM sends, and those Cohere numbers itself, are
        # identified as doc:N where N is the document's position.
        def source_index(source)
          id = source && source['id']
          return unless id.is_a?(String)

          match = id.match(/\Adoc:(\d+)\z/)
          match && match[1].to_i
        end
      end
    end
  end
end
