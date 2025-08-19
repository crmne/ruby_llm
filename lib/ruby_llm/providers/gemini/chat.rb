# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        module_function

        def completion_url
          "models/#{@model}:generateContent"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          @model = model
          payload = {
            contents: format_messages(messages),
            generationConfig: {}
          }

          payload[:generationConfig][:temperature] = temperature unless temperature.nil?

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
          when :system, :tool then 'user'
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
            output_tokens: calculate_output_tokens(data),
            model_id: data['modelVersion'] || response.env.url.path.split('/')[3].split(':')[0],
            raw: response
          )
        end

        def convert_schema_to_gemini(schema) # rubocop:disable Metrics/PerceivedComplexity
          return nil unless schema

          result = case schema[:type]
                   when 'object'
                     properties = schema[:properties]&.transform_values { |prop| convert_schema_to_gemini(prop) } || {}
                     object_result = {
                       type: 'OBJECT',
                       properties: properties,
                       required: schema[:required] || []
                     }
                     object_result[:propertyOrdering] = schema[:propertyOrdering] if schema[:propertyOrdering]
                     object_result[:nullable] = schema[:nullable] if schema.key?(:nullable)
                     object_result
                   when 'array'
                     {
                       type: 'ARRAY',
                       items: schema[:items] ? convert_schema_to_gemini(schema[:items]) : { type: 'STRING' }
                     }
                   when 'number'
                     { type: 'NUMBER' }
                   when 'integer'
                     { type: 'INTEGER' }
                   when 'boolean'
                     { type: 'BOOLEAN' }
                   else
                     { type: 'STRING' }
                   end

          result[:description] = schema[:description] if schema[:description]

          case schema[:type]
          when 'string'
            result[:enum] = schema[:enum] if schema[:enum]
            result[:format] = schema[:format] if schema[:format]
            result[:nullable] = schema[:nullable] if schema.key?(:nullable)
          when 'number', 'integer'
            result[:format] = schema[:format] if schema[:format]
            result[:minimum] = schema[:minimum] if schema[:minimum]
            result[:maximum] = schema[:maximum] if schema[:maximum]
            result[:enum] = schema[:enum] if schema[:enum]
            result[:nullable] = schema[:nullable] if schema.key?(:nullable)
          when 'array'
            result[:minItems] = schema[:minItems] if schema[:minItems]
            result[:maxItems] = schema[:maxItems] if schema[:maxItems]
            result[:nullable] = schema[:nullable] if schema.key?(:nullable)
          when 'boolean'
            result[:nullable] = schema[:nullable] if schema.key?(:nullable)
          end

          result
        end

        def extract_content(data)
          candidate = data.dig('candidates', 0)
          return '' unless candidate

          return '' if function_call?(candidate)

          parts = candidate.dig('content', 'parts')
          text_parts = parts&.select { |p| p['text'] }
          return '' unless text_parts&.any?

          text_parts.map { |p| p['text'] }.join
        end

        def function_call?(candidate)
          parts = candidate.dig('content', 'parts')
          parts&.any? { |p| p['functionCall'] }
        end

        def calculate_output_tokens(data)
          candidates = data.dig('usageMetadata', 'candidatesTokenCount') || 0
          thoughts = data.dig('usageMetadata', 'thoughtsTokenCount') || 0
          candidates + thoughts
        end
      end
    end
  end
end
