# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Chat methods of the OpenAI Responses API
      module Chat
        def completion_url
          'responses'
        end

        OPENAI_INLINE_FILE_LIMIT = 50 * 1024 * 1024
        OPENAI_FILE_UPLOAD_LIMIT = 512 * 1024 * 1024
        PROMPT_CACHE_OPTIONS = %i[key retention].freeze

        module_function

        # rubocop:disable Metrics/ParameterLists,Metrics/PerceivedComplexity
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil, schema: nil,
                           thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)
          tool_prefs ||= {}
          payload = {
            model: model.id,
            input: format_input(messages),
            instructions: format_instructions(messages),
            stream: stream,
            store: false
          }.compact

          payload[:include] = ['reasoning.encrypted_content'] if reasoning_model?(model.id)
          payload[:temperature] = temperature unless temperature.nil?
          payload[:max_output_tokens] = max_output_tokens unless max_output_tokens.nil?

          if tools.any?
            payload[:tools] = tools.map { |_, tool| tool_for(tool) }
            payload[:tool_choice] = build_tool_choice(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
            payload[:parallel_tool_calls] = tool_prefs[:calls] == :many unless tool_prefs[:calls].nil?
          end

          payload[:text] = { format: schema_format(schema) } if schema

          effort = resolve_effort(thinking)
          payload[:reasoning] = { effort: effort } if effort
          payload.merge!(prompt_cache_params(caching)) if caching

          payload
        end
        # rubocop:enable Metrics/ParameterLists,Metrics/PerceivedComplexity

        def parse_completion_body(data, raw:)
          raise Error.new(data.dig('error', 'message'), response: raw) if data.dig('error', 'message')

          output = data['output'] || []
          content = parse_output_text(output)

          finish_reason = data.dig('incomplete_details', 'reason')

          Message.new(
            role: :assistant,
            content: content,
            citations: parse_output_citations(output, content),
            thinking: Thinking.build(
              text: parse_reasoning_summary(output),
              signature: parse_reasoning_signature(output)
            ),
            tool_calls: parse_function_calls(output, response: raw, finish_reason: finish_reason),
            model: data['model'],
            raw: raw,
            finish_reason: finish_reason,
            **parse_usage(data['usage'] || {})
          )
        end

        def parse_output_citations(output, content)
          annotations = output.select { |item| item['type'] == 'message' }.flat_map do |message|
            Array(message['content']).flat_map { |part| Array(part['annotations']) }
          end

          parse_annotations(annotations, content)
        end

        def reasoning_model?(model_id)
          model_id.match?(/^o\d|^gpt-5/)
        end

        def prompt_cache_params(caching)
          options = prompt_cache_options(caching)

          {}.tap do |params|
            params[:prompt_cache_key] = options[:key] if options[:key]
            params[:prompt_cache_retention] = options[:retention] if options[:retention]
          end
        end

        def prompt_cache_options(caching)
          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                "Responses prompt caching accepts :key and :retention, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def parse_usage(usage)
          cached = usage.dig('input_tokens_details', 'cached_tokens')
          input = usage['input_tokens']

          {
            input_tokens: input && [input.to_i - cached.to_i, 0].max,
            output_tokens: usage['output_tokens'],
            cache_read_tokens: cached,
            thinking_tokens: usage.dig('output_tokens_details', 'reasoning_tokens')
          }
        end

        def schema_format(schema)
          {
            type: 'json_schema',
            name: schema[:name],
            schema: schema[:schema],
            strict: schema[:strict]
          }
        end

        def format_instructions(messages)
          instructions = messages.select { |msg| msg.role == :system }.map do |msg|
            msg.content.to_s
          end

          instructions.empty? ? nil : instructions.join("\n\n")
        end

        def format_input(messages)
          messages.reject { |msg| msg.role == :system }.flat_map { |msg| format_item(msg) }
        end

        def format_item(msg)
          case msg.role
          when :tool
            format_tool_items(msg)
          when :assistant
            format_assistant_items(msg)
          else
            { role: 'user', content: format_content(msg.content, msg.attachments) }
          end
        end

        # Function call outputs are text-only on the wire, so tool attachments
        # ride a user item spliced in right after the result.
        def format_tool_items(msg)
          items = [{
            type: 'function_call_output',
            call_id: msg.tool_call_id,
            output: format_content(msg.content)
          }]

          if msg.attachments.any?
            parts = [{ type: 'input_text', text: "Attachments from tool call #{msg.tool_call_id}:" }]
            parts.concat(Media.format_content(nil, msg.attachments))
            items << { role: 'user', content: parts }
          end

          items
        end

        def format_assistant_items(msg)
          items = []
          items << format_reasoning_item(msg.thinking) if msg.thinking&.signature
          items << { role: 'assistant', content: format_output_content(msg) } unless empty_content?(msg.content)
          items.concat(format_function_call_items(msg.tool_calls)) if msg.tool_call?
          items
        end

        def format_reasoning_item(thinking)
          {
            type: 'reasoning',
            summary: thinking.text ? [{ type: 'summary_text', text: thinking.text }] : [],
            encrypted_content: thinking.signature
          }
        end

        def format_function_call_items(tool_calls)
          tool_calls.map do |_, tc|
            {
              type: 'function_call',
              call_id: tc.id,
              name: tc.name,
              arguments: JSON.generate(tc.arguments)
            }
          end
        end

        def format_output_content(msg)
          [{ type: 'output_text', text: msg.content }]
        end

        def empty_content?(content)
          content.nil? || content.strip.empty?
        end

        def parse_output_text(output)
          texts = output.select { |item| item['type'] == 'message' }.flat_map do |message|
            Array(message['content']).filter_map { |part| part['text'] if part['type'] == 'output_text' }
          end

          texts.empty? ? nil : texts.join
        end

        def parse_function_calls(output, response: nil, finish_reason: nil)
          calls = output.select { |item| item['type'] == 'function_call' }
          return nil if calls.empty?

          calls.to_h do |call|
            arguments = call['arguments']

            [
              call['call_id'],
              ToolCall.new(
                id: call['call_id'],
                name: call['name'],
                arguments: parse_function_call_arguments(arguments, response: response, finish_reason: finish_reason)
              )
            ]
          end
        end

        def parse_function_call_arguments(arguments, response: nil, finish_reason: nil)
          return {} if arguments.nil? || arguments.empty?

          JSON.parse(arguments)
        rescue JSON::ParserError => e
          raise ToolCallParseError.new(response: response, finish_reason: finish_reason), cause: e
        end

        def parse_reasoning_summary(output)
          texts = output.select { |item| item['type'] == 'reasoning' }.flat_map do |item|
            Array(item['summary']).filter_map { |part| part['text'] }
          end

          texts.empty? ? nil : texts.join("\n")
        end

        def parse_reasoning_signature(output)
          output.find { |item| item['type'] == 'reasoning' }&.dig('encrypted_content')
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          OPENAI_INLINE_FILE_LIMIT
        end

        def provider_file_upload_limit
          OPENAI_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf?
        end

        def provider_file_upload_options(_attachment)
          { purpose: 'user_data' }
        end
      end
    end
  end
end
