# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        module_function

        def completion_url
          "models/#{@model}:generateContent"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          @model = model # Store model for completion_url/stream_url
          payload = {
            contents: format_messages(messages),
            generationConfig: {
              temperature: temperature
            }
          }

          if schema
            payload[:generationConfig][:responseMimeType] = 'application/json'
            payload[:generationConfig][:responseSchema] = convert_schema_to_gemini(schema)
          end

          payload[:tools] = format_tools(tools) if tools.any?
          payload
        end

        private

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              parts: format_parts(msg)
            }
          end
        end

        def format_role(role)
          case role
          when :assistant then 'model'
          when :system, :tool then 'user' # Gemini doesn't have system, use user role, function responses use user role
          else role.to_s
          end
        end

        def format_parts(msg)
          if msg.tool_call?
            [{
              functionCall: {
                name: msg.tool_calls.values.first.name,
                args: msg.tool_calls.values.first.arguments
              }
            }]
          elsif msg.tool_result?
            [{
              functionResponse: {
                name: msg.tool_call_id,
                response: {
                  name: msg.tool_call_id,
                  content: msg.content
                }
              }
            }]
          else
            Media.format_content(msg.content)
          end
        end

        def parse_completion_response(response)
          data = response.body
          tool_calls = extract_tool_calls(data)

          Message.new(
            role: :assistant,
            content: extract_content(data),
            tool_calls: tool_calls,
            input_tokens: data.dig('usageMetadata', 'promptTokenCount'),
            output_tokens: data.dig('usageMetadata', 'candidatesTokenCount'),
            model_id: data['modelVersion'] || response.env.url.path.split('/')[3].split(':')[0],
            raw: response
          )
        end

        def convert_schema_to_gemini(schema) # rubocop:disable Metrics/PerceivedComplexity
          return nil unless schema

          case schema[:type]
          when 'object'
            {
              type: 'OBJECT',
              properties: schema[:properties]&.transform_values { |prop| convert_schema_to_gemini(prop) } || {},
              required: schema[:required] || []
            }
          when 'array'
            {
              type: 'ARRAY',
              items: schema[:items] ? convert_schema_to_gemini(schema[:items]) : { type: 'STRING' }
            }
          when 'string'
            result = { type: 'STRING' }
            result[:enum] = schema[:enum] if schema[:enum]
            result
          when 'number', 'integer'
            { type: 'NUMBER' }
          when 'boolean'
            { type: 'BOOLEAN' }
          else
            { type: 'STRING' }
          end
        end

        def extract_content(data)
          candidate = data.dig('candidates', 0)
          return '' unless candidate

          # Content will be empty for function calls
          return '' if function_call?(candidate)

          # Extract text content
          parts = candidate.dig('content', 'parts')
          text_parts = parts&.select { |p| p['text'] }
          return '' unless text_parts&.any?

          text_parts.map { |p| p['text'] }.join
        end

        def function_call?(candidate)
          parts = candidate.dig('content', 'parts')
          parts&.any? { |p| p['functionCall'] }
        end
      end
    end
  end
end
