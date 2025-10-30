# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Chat methods of the OpenAI API integration
      module Chat
        module_function

        def completion_url
          '/v1/messages'
        end

        def render_payload(messages, tools:, temperature:, model:, thinking:, # rubocop:disable Metrics/ParameterLists
                           thinking_budget:, stream: false, schema: nil)
          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages, schema)

          build_base_payload(chat_messages, model, stream).tap do |payload|
            add_optional_fields(payload, system_content:, tools:, temperature:, thinking:, thinking_budget:)
          end
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages, schema)
          if system_messages.length > 1
            RubyLLM.logger.warn(
              "Anthropic's Claude implementation only supports a single system message. " \
              'Multiple system messages will be combined into one.'
            )
          end

          messages = system_messages.flat_map do |msg|
            content = msg.content

            if content.is_a?(RubyLLM::Content::Raw)
              content.value
            else
              Media.format_content(content)
            end
          end

          return messages unless schema

          messages << { text: "You should respond with json that follows this schema: #{schema}",
                        type: 'text' }
        end

        def build_base_payload(chat_messages, model, stream)
          {
            model: model.id,
            messages: chat_messages.map { |msg| format_message(msg) }.flatten,
            stream: stream,
            max_tokens: model.max_tokens || 4096
          }
        end

        def add_optional_fields(payload, system_content:, tools:, thinking:, thinking_budget:, temperature:) # rubocop:disable Metrics/ParameterLists
          payload[:tools] = tools.values.map { |t| Tools.function_for(t) } if tools.any?
          payload[:system] = system_content unless system_content.empty?
          payload[:temperature] = temperature unless temperature.nil?
          return unless thinking

          payload[:thinking] = {
            type: 'enabled',
            budget_tokens: thinking_budget
          }
        end

        def parse_completion_response(response)
          data = response.body
          RubyLLM.logger.debug("Anthropic response: #{data}")

          content_blocks = data['content'] || []

          thinking_content, signature = extract_thinking_content(content_blocks)
          text_content = extract_text_content(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, tool_use_blocks, thinking_content, signature, response)
        end

        def extract_thinking_content(blocks)
          thinking_blocks = blocks.select { |c| c['type'] == 'thinking' }
          thinking = thinking_blocks.map { |c| c['thinking'] }.join
          signature = thinking_blocks.filter_map { |c| c['signature'] }.compact.first
          [thinking, signature]
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['type'] == 'text' }
          text_blocks.map { |c| c['text'] }.join
        end

        def build_message(data, content, tool_use_blocks, thinking_content, signature, response) # rubocop:disable Metrics/ParameterLists
          usage = data['usage'] || {}
          cached_tokens = usage['cache_read_input_tokens']
          cache_creation_tokens = usage['cache_creation_input_tokens']
          if cache_creation_tokens.nil? && usage['cache_creation'].is_a?(Hash)
            cache_creation_tokens = usage['cache_creation'].values.compact.sum
          end

          Message.new(
            role: :assistant,
            content: content,
            thinking: thinking_content,
            signature: signature,
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: cache_creation_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_message(msg)
          if msg.tool_call?
            Tools.format_tool_call(msg)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message(msg)
          end
        end

        def format_basic_message(msg)
          {
            role: convert_role(msg.role),
            content: Media.format_content(msg.content)
          }
        end

        def convert_role(role)
          case role
          when :tool, :user then 'user'
          else 'assistant'
          end
        end
      end
    end
  end
end
