# frozen_string_literal: true

module RubyLLM
  module Providers
    class TogetherAI
      # Chat methods for the Together.ai provider
      module Chat
        def completion_url
          'chat/completions'
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model.id,
            messages: format_messages(messages),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?
          payload[:tools] = tools.map { |_, tool| tool_for(tool) } if tools.any?

          # Together.ai supports structured output via response_format
          if schema
            payload[:response_format] = {
              type: 'json_schema',
              json_schema: {
                name: 'response',
                schema: schema
              }
            }
          end

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

          Message.new(
            role: :assistant,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: 0,
            cache_creation_tokens: 0,
            model_id: data['model'],
            raw: response
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg.role.to_s,
              content: format_content(msg.content),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end

        def format_content(content)
          # Together.ai expects simple string content for most cases
          case content
          when String
            content
          when Array
            # For multimodal content, extract text parts
            text_parts = content.select { |part| part.is_a?(Hash) && part['type'] == 'text' }
            text_parts.map { |part| part['text'] }.join(' ')
          else
            content.to_s
          end
        end

        def format_tool_calls(tool_calls)
          return unless tool_calls&.any?

          tool_calls.map do |tool_call|
            {
              id: tool_call.id,
              type: 'function',
              function: {
                name: tool_call.name,
                arguments: tool_call.arguments.to_json
              }
            }
          end
        end

        def parse_tool_calls(tool_calls_data)
          return [] unless tool_calls_data&.any?

          tool_calls_data.map do |tool_call|
            ToolCall.new(
              id: tool_call['id'],
              name: tool_call.dig('function', 'name'),
              arguments: JSON.parse(tool_call.dig('function', 'arguments') || '{}')
            )
          rescue JSON::ParserError
            ToolCall.new(
              id: tool_call['id'],
              name: tool_call.dig('function', 'name'),
              arguments: {}
            )
          end
        end

        def tool_for(tool)
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters
            }
          }
        end
      end
    end
  end
end
