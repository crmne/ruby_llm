# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Chat methods of the OpenAI API integration
      module Chat
        def completion_url
          'chat/completions'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model.id,
            messages: format_messages(messages),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?
          payload[:tools] = tools.map { |_, tool| tool_for(tool) } if tools.any?

          if schema
            strict = schema[:strict] != false

            payload[:response_format] = {
              type: 'json_schema',
              json_schema: {
                name: 'response',
                schema: schema,
                strict: strict
              }
            }
          end

          effort = resolve_effort(thinking)
          payload[:reasoning_effort] = effort if effort

          payload[:stream_options] = { include_usage: true } if stream
          payload
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          return unless message_data

          usage = data['usage'] || {}
          cached_tokens = usage.dig('prompt_tokens_details', 'cached_tokens')
          thinking_tokens = usage.dig('completion_tokens_details', 'reasoning_tokens')
          content, thinking_from_blocks = extract_content_and_thinking(message_data['content'])
          thinking_text = thinking_from_blocks || extract_thinking_text(message_data)
          thinking_signature = extract_thinking_signature(message_data)

          Message.new(
            role: :assistant,
            content: content,
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0,
            thinking_tokens: thinking_tokens,
            model_id: data['model'],
            raw: response
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: Media.format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(format_thinking(msg))
          end
        end

        def format_role(role)
          case role
          when :system
            @config.openai_use_system_role ? 'system' : 'developer'
          else
            role.to_s
          end
        end

        def resolve_effort(thinking)
          return nil unless thinking

          thinking.respond_to?(:effort) ? thinking.effort : thinking
        end

        def format_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          return {} unless thinking

          payload = {}
          if thinking.text
            payload[:reasoning] = thinking.text
            payload[:reasoning_content] = thinking.text
          end
          payload[:reasoning_signature] = thinking.signature if thinking.signature
          payload
        end

        def extract_thinking_text(message_data)
          candidate = message_data['reasoning_content'] || message_data['reasoning'] || message_data['thinking']
          candidate.is_a?(String) ? candidate : nil
        end

        def extract_thinking_signature(message_data)
          candidate = message_data['reasoning_signature'] || message_data['signature']
          candidate.is_a?(String) ? candidate : nil
        end

        def extract_content_and_thinking(content)
          return extract_think_tag_content(content) if content.is_a?(String)
          return [content, nil] unless content.is_a?(Array)

          text = extract_text_from_blocks(content)
          thinking = extract_thinking_from_blocks(content)

          [text.empty? ? nil : text, thinking.empty? ? nil : thinking]
        end

        def extract_text_from_blocks(blocks)
          blocks.filter_map do |block|
            block['text'] if block['type'] == 'text' && block['text'].is_a?(String)
          end.join
        end

        def extract_thinking_from_blocks(blocks)
          blocks.filter_map do |block|
            next unless block['type'] == 'thinking'

            extract_thinking_text_from_block(block)
          end.join
        end

        def extract_thinking_text_from_block(block)
          thinking_block = block['thinking']
          return thinking_block if thinking_block.is_a?(String)

          if thinking_block.is_a?(Array)
            return thinking_block.filter_map { |item| item['text'] if item['type'] == 'text' }.join
          end

          block['text'] if block['text'].is_a?(String)
        end

        def extract_think_tag_content(text)
          return [text, nil] unless text.include?('<think>')

          thinking = text.scan(%r{<think>(.*?)</think>}m).join
          content = text.gsub(%r{<think>.*?</think>}m, '').strip

          [content.empty? ? nil : content, thinking.empty? ? nil : thinking]
        end
      end
    end
  end
end
