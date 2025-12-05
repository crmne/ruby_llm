# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Validates JSON schemas for Anthropic structured outputs
      class SchemaValidator
        def initialize(schema)
          @schema = schema
        end

        def validate!
          validate_node(@schema, 'schema')
        end

        private

        def validate_node(schema, path)
          return unless schema.is_a?(Hash)

          validate_object_schema(schema, path)
          validate_properties(schema, path)
          validate_items(schema, path)
          validate_combinators(schema, path)
        end

        def validate_object_schema(schema, path)
          return unless value(schema, :type) == 'object' && value(schema, :additionalProperties) != false

          raise ArgumentError,
                "#{path}: Object schemas must set 'additionalProperties' to false for Anthropic structured outputs."
        end

        def validate_properties(schema, path)
          properties = value(schema, :properties)
          return unless properties.is_a?(Hash)

          properties.each do |key, prop_schema|
            validate_node(prop_schema, "#{path}.properties.#{key}")
          end
        end

        def validate_items(schema, path)
          items = value(schema, :items)
          validate_node(items, "#{path}.items") if items
        end

        def validate_combinators(schema, path)
          %i[anyOf oneOf allOf].each do |keyword|
            schemas = value(schema, keyword)
            next unless schemas.is_a?(Array)

            schemas.each_with_index do |sub_schema, index|
              validate_node(sub_schema, "#{path}.#{keyword}[#{index}]")
            end
          end
        end

        def value(schema, key)
          return unless schema.is_a?(Hash)

          symbol_key = key.is_a?(Symbol) ? key : key.to_sym
          return schema[symbol_key] if schema.key?(symbol_key)

          string_key = key.to_s
          schema[string_key] if schema.key?(string_key)
        end
      end
    end
  end
end
