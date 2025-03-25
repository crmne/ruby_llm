# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Handles conversion of schema formats to Gemini-specific formats
      module Schema
        module_function

        # Convert a schema to Gemini's response_schema format
        #
        # @param format [Class, Hash, String] The format specification
        # @return [Hash] A Gemini-compatible schema
        def convert(format)
          schema = SchemaConverter.extract_schema(format)

          # Convert the schema to Gemini's format which uses different case conventions
          # and type naming
          # https://ai.google.dev/gemini-api/docs/structured-output?lang=rest
          convert_schema_format(schema)
        end

        # Convert a standard JSON schema to Gemini's specific format
        #
        # @param schema [Hash] A standard JSON schema
        # @return [Hash] A Gemini-compatible schema
        def convert_schema_format(schema)
          result = {}

          if schema[:type]
            result[:type] = convert_type(schema[:type])
          end

          if schema[:properties]
            result[:properties] = {}
            schema[:properties].each do |key, prop|
              result[:properties][key] = convert_schema_format(prop)
            end
          end

          if schema[:items]
            result[:items] = convert_schema_format(schema[:items])
          end

          if schema[:required]
            result[:required] = schema[:required]
          end

          if schema[:enum]
            result[:enum] = schema[:enum]
          end

          if schema[:format]
            result[:format] = schema[:format]
          end

          result
        end

        # Convert JSON Schema type names to Gemini type names
        #
        # @param type [String] JSON Schema type name
        # @return [String] Gemini type name
        def convert_type(type)
          case type.to_s.downcase
          when 'object' then 'OBJECT'
          when 'array' then 'ARRAY'
          when 'string' then 'STRING'
          when 'number' then 'NUMBER'
          when 'integer' then 'INTEGER'
          when 'boolean' then 'BOOLEAN'
          else type.to_s.upcase
          end
        end
      end
    end
  end
end