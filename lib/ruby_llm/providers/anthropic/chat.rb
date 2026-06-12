# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Chat methods for the Anthropic API implementation
      module Chat
        module_function

        def completion_url
          'v1/messages'
        end

        # rubocop:disable Metrics/ParameterLists
        def render_payload(messages, tools:, temperature:, model:, stream: false,
                           schema: nil, thinking: nil, citations: false, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.citations?
          tool_prefs ||= {}
          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages)

          build_base_payload(chat_messages, model, stream, thinking, citations: citations).tap do |payload|
            add_optional_fields(payload, system_content:, tools:, tool_prefs:, temperature:, schema:)
          end
        end
        # rubocop:enable Metrics/ParameterLists

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'with_citations may have no effect.'
          )
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages)
          return [] if system_messages.empty?

          # Anthropic's `system` parameter accepts an array of text content blocks
          # (each optionally with cache_control); each :system message becomes its
          # own block in the resulting array.
          system_messages.flat_map do |msg|
            content = msg.content

            if content.is_a?(RubyLLM::Content::Raw)
              content.value
            else
              Media.format_content(content)
            end
          end
        end

        def build_base_payload(chat_messages, model, stream, thinking, citations: false)
          payload = {
            model: model.id,
            messages: chat_messages.map { |msg| format_message(msg, thinking: thinking, citations: citations) },
            stream: stream,
            max_tokens: model.max_tokens || 4096
          }

          add_thinking_fields(payload, thinking, model)

          payload
        end

        def add_optional_fields(payload, system_content:, tools:, tool_prefs:, temperature:, schema: nil) # rubocop:disable Metrics/ParameterLists
          if tools.any?
            payload[:tools] = tools.values.map { |t| Tools.function_for(t) }
            unless tool_prefs[:choice].nil? && tool_prefs[:calls].nil?
              payload[:tool_choice] = Tools.build_tool_choice(tool_prefs)
            end
          end
          payload[:system] = system_content unless system_content.empty?
          payload[:temperature] = temperature unless temperature.nil?
          payload[:output_config] = payload.fetch(:output_config, {}).merge(build_output_config(schema)) if schema
        end

        def build_output_config(schema)
          normalized = RubyLLM::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')
          { format: { type: 'json_schema', schema: normalized } }
        end

        def parse_completion_response(response)
          data = response.body
          content_blocks = data['content'] || []

          text_content, citations = extract_text_and_citations(content_blocks)
          thinking_content = extract_thinking_content(content_blocks)
          thinking_signature = extract_thinking_signature(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, citations, thinking_content, thinking_signature, tool_use_blocks,
                        response)
        end

        def extract_text_and_citations(blocks)
          text = +''
          citations = []

          blocks.each do |block|
            next unless block['type'] == 'text'

            block_text = block['text'].to_s
            Array(block['citations']).each do |citation|
              citations << parse_citation(citation, text: block_text,
                                                    start_index: text.length,
                                                    end_index: text.length + block_text.length)
            end
            text << block_text
          end

          [text, citations]
        end

        def parse_citation(data, text: nil, start_index: nil, end_index: nil)
          end_page = data['end_page_number']

          Citation.new(
            url: citation_url(data),
            title: data['document_title'] || data['title'],
            cited_text: data['cited_text'],
            text: text,
            start_index: start_index,
            end_index: end_index,
            source_index: data['document_index'] || data['search_result_index'],
            start_page: data['start_page_number'],
            end_page: end_page && (end_page - 1)
          )
        end

        # Search result citations carry the developer-provided source string.
        def citation_url(data)
          url = data['url'] || data['source']
          url if url&.match?(%r{\Ahttps?://})
        end

        def extract_thinking_content(blocks)
          thinking_blocks = blocks.select { |c| c['type'] == 'thinking' }
          thoughts = thinking_blocks.map { |c| c['thinking'] || c['text'] }.join
          thoughts.empty? ? nil : thoughts
        end

        def extract_thinking_signature(blocks)
          thinking_block = blocks.find { |c| c['type'] == 'thinking' } ||
                           blocks.find { |c| c['type'] == 'redacted_thinking' }
          thinking_block&.dig('signature') || thinking_block&.dig('data')
        end

        def build_message(data, content, citations, thinking, thinking_signature, tool_use_blocks, response) # rubocop:disable Metrics/ParameterLists
          usage = data['usage'] || {}
          thinking_tokens = usage.dig('output_tokens_details', 'thinking_tokens') ||
                            usage.dig('output_tokens_details', 'reasoning_tokens') ||
                            usage['thinking_tokens'] ||
                            usage['reasoning_tokens']

          Message.new(
            role: :assistant,
            content: content,
            citations: citations,
            thinking: Thinking.build(text: thinking, signature: thinking_signature),
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: extract_cached_tokens(data),
            cache_creation_tokens: extract_cache_creation_tokens(data),
            thinking_tokens: thinking_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_message(msg, thinking: nil, citations: false)
          thinking_enabled = thinking&.enabled?

          if msg.tool_call?
            format_tool_call_with_thinking(msg, thinking_enabled)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message_with_thinking(msg, thinking_enabled, citations: citations)
          end
        end

        def format_basic_message_with_thinking(msg, thinking_enabled, citations: false)
          content_blocks = []

          if msg.role == :assistant && thinking_enabled
            thinking_block = build_thinking_block(msg.thinking)
            content_blocks << thinking_block if thinking_block
          end

          append_formatted_content(content_blocks, msg.content, citations: citations)

          {
            role: convert_role(msg.role),
            content: content_blocks
          }
        end

        def format_tool_call_with_thinking(msg, thinking_enabled)
          if msg.content.is_a?(RubyLLM::Content::Raw)
            content_blocks = msg.content.value
            content_blocks = [content_blocks] unless content_blocks.is_a?(Array)
            content_blocks = prepend_thinking_block(content_blocks, msg, thinking_enabled)

            return { role: 'assistant', content: content_blocks }
          end

          content_blocks = prepend_thinking_block([], msg, thinking_enabled)
          append_formatted_content(content_blocks, msg.content) unless msg.content.nil? || msg.content.empty?

          msg.tool_calls.each_value do |tool_call|
            content_blocks << {
              type: 'tool_use',
              id: tool_call.id,
              name: tool_call.name,
              input: tool_call.arguments
            }
          end

          {
            role: 'assistant',
            content: content_blocks
          }
        end

        def prepend_thinking_block(content_blocks, msg, thinking_enabled)
          return content_blocks unless thinking_enabled

          thinking_block = build_thinking_block(msg.thinking)
          content_blocks.unshift(thinking_block) if thinking_block

          content_blocks
        end

        def build_thinking_block(thinking)
          return nil unless thinking

          if thinking.text
            {
              type: 'thinking',
              thinking: thinking.text,
              signature: thinking.signature
            }.compact
          elsif thinking.signature
            {
              type: 'redacted_thinking',
              data: thinking.signature
            }
          end
        end

        def append_formatted_content(content_blocks, content, citations: false)
          formatted_content = Media.format_content(content, citations: citations)
          if formatted_content.is_a?(Array)
            content_blocks.concat(formatted_content)
          else
            content_blocks << formatted_content
          end
        end

        def convert_role(role)
          case role
          when :tool, :user then 'user'
          else 'assistant'
          end
        end

        def add_thinking_fields(payload, thinking, model)
          thinking_payload = build_thinking_payload(thinking, model)
          return unless thinking_payload

          payload[:thinking] = thinking_payload[:thinking] if thinking_payload[:thinking]
          return unless thinking_payload[:output_config]

          payload[:output_config] = payload.fetch(:output_config, {}).merge(thinking_payload[:output_config])
        end

        def build_thinking_payload(thinking, model)
          return nil unless thinking&.enabled?

          effort = resolve_effort(thinking)
          return nil if effort == 'none'

          budget = resolve_budget(thinking)
          if budget
            return enabled_thinking_payload(budget) if model.reasoning_option('budget_tokens')

            raise ArgumentError, "Anthropic thinking budget is not supported for #{model.id}"
          end

          raise ArgumentError, 'Anthropic adaptive thinking requires an effort' if effort.nil?
          return adaptive_thinking_payload(effort) if model.reasoning_option('effort')

          raise ArgumentError, "Anthropic thinking effort is not supported for #{model.id}"
        end

        def enabled_thinking_payload(budget)
          {
            thinking: {
              type: 'enabled',
              budget_tokens: budget
            }
          }
        end

        def adaptive_thinking_payload(effort)
          {
            thinking: { type: 'adaptive' },
            output_config: { effort: effort }
          }
        end

        def resolve_effort(thinking)
          effort = thinking.effort.to_s
          effort.empty? ? nil : effort
        end

        def resolve_budget(thinking)
          thinking.budget
        end
      end
    end
  end
end
