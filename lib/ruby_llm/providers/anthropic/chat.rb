# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Chat methods for the Anthropic API implementation
      module Chat
        module_function

        def completion_url
          '/v1/messages'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages)

          build_base_payload(chat_messages, model, stream, thinking).tap do |payload|
            add_optional_fields(payload, system_content:, tools:, temperature:)
          end
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages)
          return [] if system_messages.empty?

          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Anthropic's Claude implementation only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          system_messages.flat_map do |msg|
            content = msg.content

            if content.is_a?(RubyLLM::Content::Raw)
              content.value
            else
              Media.format_content(content)
            end
          end
        end

        def build_base_payload(chat_messages, model, stream, thinking)
          payload = {
            model: model.id,
            messages: chat_messages.map { |msg| format_message(msg, thinking: thinking) },
            stream: stream,
            max_tokens: model.max_tokens || 4096
          }

          thinking_payload = build_thinking_payload(thinking)
          payload[:thinking] = thinking_payload if thinking_payload

          payload
        end

        def add_optional_fields(payload, system_content:, tools:, temperature:)
          payload[:tools] = tools.values.map { |t| Tools.function_for(t) } if tools.any?
          payload[:system] = system_content unless system_content.empty?
          payload[:temperature] = temperature unless temperature.nil?
        end

        def parse_completion_response(response)
          data = response.body
          content_blocks = data['content'] || []

          text_content = extract_text_content(content_blocks)
          thinking_content = extract_thinking_content(content_blocks)
          thinking_signature = extract_thinking_signature(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, thinking_content, thinking_signature, tool_use_blocks, response)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['type'] == 'text' }
          text_blocks.map { |c| c['text'] }.join
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

        def build_message(data, content, thinking, thinking_signature, tool_use_blocks, response) # rubocop:disable Metrics/ParameterLists
          usage = data['usage'] || {}
          cached_tokens = usage['cache_read_input_tokens']
          cache_creation_tokens = usage['cache_creation_input_tokens']
          if cache_creation_tokens.nil? && usage['cache_creation'].is_a?(Hash)
            cache_creation_tokens = usage['cache_creation'].values.compact.sum
          end
          thinking_tokens = usage.dig('output_tokens_details', 'thinking_tokens') ||
                            usage.dig('output_tokens_details', 'reasoning_tokens') ||
                            usage['thinking_tokens'] ||
                            usage['reasoning_tokens']

          Message.new(
            role: :assistant,
            content: content,
            thinking: Thinking.build(text: thinking, signature: thinking_signature),
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: cache_creation_tokens,
            thinking_tokens: thinking_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_message(msg, thinking: nil)
          thinking_enabled = thinking&.enabled?

          if msg.tool_call?
            format_tool_call_with_thinking(msg, thinking_enabled)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message_with_thinking(msg, thinking_enabled)
          end
        end

        def format_basic_message_with_thinking(msg, thinking_enabled)
          content_blocks = []

          if msg.role == :assistant && thinking_enabled
            thinking_block = build_thinking_block(msg.thinking)
            content_blocks << thinking_block if thinking_block
          end

          append_formatted_content(content_blocks, msg.content)

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
          content_blocks << Media.format_text(msg.content) unless msg.content.nil? || msg.content.empty?

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

        def append_formatted_content(content_blocks, content)
          formatted_content = Media.format_content(content)
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

        def build_thinking_payload(thinking)
          return nil unless thinking&.enabled?

          budget = resolve_budget(thinking)
          raise ArgumentError, 'Anthropic thinking requires a budget' if budget.nil?

          {
            type: 'enabled',
            budget_tokens: budget
          }
        end

        def resolve_budget(thinking)
          budget = thinking.respond_to?(:budget) ? thinking.budget : thinking
          budget.is_a?(Integer) ? budget : nil
        end
      end
    end
  end
end
