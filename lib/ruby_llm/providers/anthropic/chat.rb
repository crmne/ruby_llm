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
            messages: chat_messages.map { |msg| format_message(msg, thinking_enabled: thinking) },
            stream: stream,
            max_tokens: calculate_max_tokens(model, thinking)
          }

          if thinking
            payload[:thinking] = {
              type: 'enabled',
              budget_tokens: resolve_budget(thinking, model)
            }
          end

          payload
        end

        def calculate_max_tokens(model, thinking)
          base = model.max_tokens || 4096
          return base unless thinking

          budget = resolve_budget(thinking, model)
          [base, budget + 8000].max
        end

        def resolve_budget(thinking, _model)
          return thinking if thinking.is_a?(Integer)

          case thinking
          when :low then 1024
          when :medium then 10_000
          when :high then 32_000
          else 10_000 # rubocop:disable Lint/DuplicateBranch
          end
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
          thinking_sig = extract_thinking_signature(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)

          build_message(data, text_content, thinking_content, thinking_sig, tool_use_blocks, response)
        end

        def extract_text_content(blocks)
          text_blocks = blocks.select { |c| c['type'] == 'text' }
          text_blocks.map { |c| c['text'] }.join
        end

        def extract_thinking_content(blocks)
          thinking_blocks = blocks.select { |c| c['type'] == 'thinking' }
          thoughts = thinking_blocks.map { |c| c['thinking'] }.join
          thoughts.empty? ? nil : thoughts
        end

        def extract_thinking_signature(blocks)
          thinking_block = blocks.find { |c| c['type'] == 'thinking' }
          thinking_block&.dig('signature')
        end

        def build_message(data, content, thinking, thinking_sig, tool_use_blocks, response) # rubocop:disable Metrics/ParameterLists
          usage = data['usage'] || {}
          cached_tokens = usage['cache_read_input_tokens']
          cache_creation_tokens = usage['cache_creation_input_tokens']
          if cache_creation_tokens.nil? && usage['cache_creation'].is_a?(Hash)
            cache_creation_tokens = usage['cache_creation'].values.compact.sum
          end

          Message.new(
            role: :assistant,
            content: content,
            thinking: thinking,
            thinking_signature: thinking_sig,
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: cache_creation_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_message(msg, thinking_enabled: false)
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
            sig = Messages.signature_for(msg)

            if msg.thinking.present?
              content_blocks << {
                type: 'thinking',
                thinking: msg.thinking,
                signature: sig
              }.compact
            elsif sig
              content_blocks << {
                type: 'redacted_thinking',
                data: sig
              }
            end
          end

          content_blocks.concat(Media.format_content(msg.content))

          {
            role: convert_role(msg.role),
            content: content_blocks
          }
        end

        def format_tool_call_with_thinking(msg, thinking_enabled)
          content_blocks = []

          if thinking_enabled && msg.thinking.present?
            sig = Messages.signature_for(msg)
            content_blocks << {
              type: 'thinking',
              thinking: msg.thinking,
              signature: sig
            }.compact
          end

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
