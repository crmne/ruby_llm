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

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
                           cache_prompts: { system: false, user: false, tools: false })
          system_messages, chat_messages = separate_messages(messages)
          system_content = build_system_content(system_messages, cache: cache_prompts[:system])

          build_base_payload(chat_messages, model, stream, cache: cache_prompts[:user]).tap do |payload|
            add_optional_fields(payload, system_content:, tools:, temperature:,
                                         cache_tools: cache_prompts[:tools])
          end
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages, cache: false)
          system_messages.flat_map.with_index do |msg, idx|
            message_cache = cache if idx == system_messages.size - 1
            format_system_message(msg, cache: message_cache)
          end
        end

        def build_base_payload(chat_messages, model, stream, cache: false)
          messages = chat_messages.map.with_index do |msg, idx|
            message_cache = cache if idx == chat_messages.size - 1
            format_message(msg, cache: message_cache)
          end

          {
            model: model,
            messages:,
            stream: stream,
            max_tokens: RubyLLM.models.find(model)&.max_tokens || 4096
          }
        end

        def add_optional_fields(payload, system_content:, tools:, temperature:, cache_tools: false)
          if tools.any?
            tool_definitions = tools.values.map { |t| Tools.function_for(t) }
            tool_definitions[-1][:cache_control] = { type: 'ephemeral' } if cache_tools
            payload[:tools] = tool_definitions
          end

          payload[:system] = system_content unless system_content.empty?
          payload[:temperature] = temperature unless temperature.nil?
        end

        def parse_completion_response(response)
          data = response.body
          content_blocks = data['content'] || []

          text_content = extract_text_content(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, tool_use_blocks, response)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['type'] == 'text' }
          text_blocks.map { |c| c['text'] }.join
        end

        def build_message(data, content, tool_use_blocks, response)
          Message.new(
            role: :assistant,
            content: content,
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: data.dig('usage', 'input_tokens'),
            output_tokens: data.dig('usage', 'output_tokens'),
            model_id: data['model'],
            cache_creation_tokens: data.dig('usage', 'cache_creation_input_tokens'),
            cached_tokens: data.dig('usage', 'cache_read_input_tokens'),
            raw: response
          )
        end

        def format_message(msg, cache: false)
          if msg.tool_call?
            Tools.format_tool_call(msg)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message(msg, cache:)
          end
        end

        def format_system_message(msg, cache: false)
          Media.format_content(msg.content, cache:)
        end

        def format_basic_message(msg, cache: false)
          {
            role: convert_role(msg.role),
            content: Media.format_content(msg.content, cache:)
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
