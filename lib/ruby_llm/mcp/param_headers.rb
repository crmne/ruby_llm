# frozen_string_literal: true

module RubyLLM
  class MCP
    # Mirrors tool arguments marked with +x-mcp-header+ into Mcp-Param-*
    # HTTP headers, as 2026-07-28 requires, so intermediaries can route on
    # them. Tools that declare invalid headers are left out entirely.
    module ParamHeaders # :nodoc:
      TOKEN = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
      TYPES = %w[string integer boolean].freeze
      SCHEMA_MAPS = %w[$defs definitions patternProperties dependentSchemas dependencies].freeze
      SCHEMA_VALUES = %w[
        items prefixItems additionalItems contains additionalProperties unevaluatedItems unevaluatedProperties
        propertyNames allOf anyOf oneOf not if then else contentSchema
      ].freeze

      module_function

      def valid?(definition)
        declared = declarations(definition)
        names = declared.map { |_, header, _| header.to_s.downcase }
        valid = declared.all? { |path, header, schema| valid_declaration?(path, header, schema) }
        return true if valid && names.uniq.size == names.size

        RubyLLM.logger.warn { "Ignoring MCP tool #{definition['name']}: it declares invalid x-mcp-header values" }
        false
      end

      def for(definition, arguments)
        declarations(definition).each_with_object({}) do |(path, header, _), headers|
          value = argument_at(arguments, path)
          headers[header] = value.to_s unless value.nil?
        end
      end

      def declarations(definition)
        schema_declarations(definition['inputSchema'], [])
      end

      def valid_declaration?(path, header, schema)
        path&.any? && header.is_a?(String) && header.match?(TOKEN) && TYPES.include?(schema['type'])
      end

      def schema_declarations(schema, path)
        return [] unless schema.is_a?(Hash)

        declared = schema.key?('x-mcp-header') ? [[path, schema['x-mcp-header'], schema]] : []
        declared + property_declarations(schema['properties'], path) +
          unreachable_schemas(schema).flat_map { |child| schema_declarations(child, nil) }
      end

      def property_declarations(properties, path)
        return [] unless properties.is_a?(Hash)

        properties.flat_map do |property, child|
          schema_declarations(child, path && [*path, property])
        end
      end

      def unreachable_schemas(schema)
        schema.flat_map do |keyword, children|
          case keyword
          when *SCHEMA_MAPS
            children.is_a?(Hash) ? children.values : []
          when *SCHEMA_VALUES
            children.is_a?(Array) ? children : [children]
          else
            []
          end
        end
      end

      def argument_at(arguments, path)
        path.reduce(arguments) do |value, property|
          break unless value.is_a?(Hash)

          argument = value[property.to_sym]
          argument.nil? ? value[property] : argument
        end
      end
    end
  end
end
