# frozen_string_literal: true

module RubyLLM
  module Providers
    class OllamaCloud
      # Chat methods using native Ollama API format
      module Chat
        def completion_url
          'api/chat'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists
          payload = {
            model: model.id,
            messages: format_messages(messages),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?

          payload[:tools] = tools.map { |_, tool| format_tool(tool) } if tools.any?

          payload[:format] = schema if schema

          # Ollama supports 'think' parameter for reasoning models
          if thinking
            payload[:think] = thinking.is_a?(Hash) ? thinking[:effort] : thinking
          end

          payload
        end

        def parse_completion_response(response)
          data = response.body
          return if data.empty?

          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          message_data = data.dig('message')
          return unless message_data

          usage = data.dig('usage') || {}

          Message.new(
            role: :assistant,
            content: message_data['content'],
            tool_calls: parse_tool_calls(message_data['tool_calls']),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            model_id: data['model'],
            raw: response
          )
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: msg.role.to_s,
              content: msg.content.to_s
            }.tap do |formatted|
              # Add tool calls if present
              formatted[:tool_calls] = msg.tool_calls if msg.tool_calls && !msg.tool_calls.empty?
            end
          end
        end

        def format_tool(tool)
          {
            type: 'function',
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters&.transform_keys(&:to_s)
            }
          }
        end

        def parse_tool_calls(tool_calls)
          return nil unless tool_calls

          tool_calls.map do |tc|
            ToolCall.new(
              id: tc.dig('id') || tc.dig('function', 'name'),
              name: tc.dig('function', 'name'),
              arguments: tc.dig('function', 'arguments')
            )
          end
        end
      end
    end
  end
end
