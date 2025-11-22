# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Tools methods for the Gemini API implementation
      module Tools
        def format_tools(tools)
          return [] if tools.empty?

          [{
            functionDeclarations: tools.values.map { |tool| function_declaration_for(tool) }
          }]
        end

        def format_tool_call(msg)
          parts = []

          if msg.content && !(msg.content.respond_to?(:empty?) && msg.content.empty?)
            formatted_content = Media.format_content(msg.content)
            parts.concat(formatted_content.is_a?(Array) ? formatted_content : [formatted_content])
          end

          msg.tool_calls.each_value do |tool_call|
            parts << {
              functionCall: {
                name: tool_call.name,
                args: tool_call.arguments
              }
            }
          end

          parts
        end

        def format_tool_result(msg, function_name = nil)
          function_name ||= msg.tool_call_id

          [{
            functionResponse: {
              name: function_name,
              response: {
                name: function_name,
                content: Media.format_content(msg.content)
              }
            }
          }]
        end

        def extract_tool_calls(data) # rubocop:disable Metrics/PerceivedComplexity
          return nil unless data

          candidate = data.is_a?(Hash) ? data.dig('candidates', 0) : nil
          return nil unless candidate

          parts = candidate.dig('content', 'parts')
          return nil unless parts.is_a?(Array)

          tool_calls = parts.each_with_object({}) do |part, result|
            function_data = part['functionCall']
            next unless function_data

            id = SecureRandom.uuid

            result[id] = ToolCall.new(
              id:,
              name: function_data['name'],
              arguments: function_data['args'] || {}
            )
          end

          tool_calls.empty? ? nil : tool_calls
        end

        private

        def function_declaration_for(tool)
          parameters_schema = tool.params_schema ||
                              RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema

          declaration = {
            name: tool.name,
            description: tool.description
          }

          declaration[:parameters] = convert_tool_schema_to_gemini(parameters_schema) if parameters_schema

          return declaration if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(declaration, tool.provider_params)
        end

        def convert_tool_schema_to_gemini(schema)
          return nil unless schema

          schema = RubyLLM::Utils.deep_stringify_keys(schema)

          raise ArgumentError, 'Gemini tool parameters must be objects' unless schema['type'] == 'object'

          {
            type: 'OBJECT',
            properties: schema.fetch('properties', {}).transform_values { |property| convert_property(property) },
            required: (schema['required'] || []).map(&:to_s)
          }
        end

        def convert_property(property_schema) # rubocop:disable Metrics/PerceivedComplexity
          normalized_schema = normalize_any_of_schema(property_schema)
          working_schema = normalized_schema || property_schema

          type = param_type_for_gemini(working_schema['type'])

          property = {
            type: type
          }

          copy_common_attributes(property, property_schema)
          copy_common_attributes(property, working_schema)

          case type
          when 'ARRAY'
            items_schema = working_schema['items'] || property_schema['items'] || { 'type' => 'string' }
            property[:items] = convert_property(items_schema)
            copy_tool_attributes(property, working_schema, %w[minItems maxItems])
            copy_tool_attributes(property, property_schema, %w[minItems maxItems])
          when 'OBJECT'
            nested_properties = working_schema.fetch('properties', {}).transform_values do |child|
              convert_property(child)
            end
            property[:properties] = nested_properties
            required = working_schema['required'] || property_schema['required']
            property[:required] = required.map(&:to_s) if required
          end

          property
        end

        def copy_common_attributes(target, source)
          copy_tool_attributes(target, source, %w[description enum format nullable maximum minimum multipleOf])
        end

        def copy_tool_attributes(target, source, attributes)
          attributes.each do |attribute|
            value = schema_value(source, attribute)
            next if value.nil?

            target[attribute.to_sym] = value
          end
        end

        def normalize_any_of_schema(schema) # rubocop:disable Metrics/PerceivedComplexity
          any_of = schema['anyOf'] || schema[:anyOf]
          return nil unless any_of.is_a?(Array) && any_of.any?

          null_entries, non_null_entries = any_of.partition { |entry| schema_type(entry).to_s == 'null' }

          if non_null_entries.size == 1 && null_entries.any?
            normalized = RubyLLM::Utils.deep_dup(non_null_entries.first)
            normalized['nullable'] = true
            normalized
          elsif non_null_entries.any?
            RubyLLM::Utils.deep_dup(non_null_entries.first)
          else
            { 'type' => 'string', 'nullable' => true }
          end
        end

        def schema_type(schema)
          schema['type'] || schema[:type]
        end

        def schema_value(source, attribute) # rubocop:disable Metrics/PerceivedComplexity
          case attribute
          when 'multipleOf'
            source['multipleOf'] || source[:multipleOf] || source['multiple_of'] || source[:multiple_of]
          when 'minItems'
            source['minItems'] || source[:minItems] || source['min_items'] || source[:min_items]
          when 'maxItems'
            source['maxItems'] || source[:maxItems] || source['max_items'] || source[:max_items]
          else
            source[attribute] || source[attribute.to_sym]
          end
        end

        def param_type_for_gemini(type)
          case type.to_s.downcase
          when 'integer' then 'INTEGER'
          when 'number', 'float', 'double' then 'NUMBER'
          when 'boolean' then 'BOOLEAN'
          when 'array' then 'ARRAY'
          when 'object' then 'OBJECT'
          else 'STRING'
          end
        end
      end
    end
  end
end
