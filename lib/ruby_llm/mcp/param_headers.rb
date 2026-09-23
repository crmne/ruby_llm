# frozen_string_literal: true

module RubyLLM
  class MCP
    # Mirrors tool arguments marked with +x-mcp-header+ into Mcp-Param-*
    # HTTP headers, as 2026-07-28 requires, so intermediaries can route on
    # them. Tools that declare invalid headers are left out entirely.
    module ParamHeaders # :nodoc:
      TOKEN = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
      TYPES = %w[string integer boolean].freeze

      module_function

      def valid?(definition)
        declared = declarations(definition).map { |_, header, schema| [header, schema['type']] }
        names = declared.map { |header, _| header.to_s.downcase }
        valid = declared.all? { |header, type| header.is_a?(String) && header.match?(TOKEN) && TYPES.include?(type) }
        return true if valid && names.uniq.size == names.size

        RubyLLM.logger.warn { "Ignoring MCP tool #{definition['name']}: it declares invalid x-mcp-header values" }
        false
      end

      def for(definition, arguments)
        declarations(definition).each_with_object({}) do |(property, header, _), headers|
          value = arguments[property.to_sym]
          value = arguments[property] if value.nil?
          headers[header] = value.to_s unless value.nil?
        end
      end

      def declarations(definition)
        definition.dig('inputSchema', 'properties').to_h.filter_map do |property, schema|
          [property, schema['x-mcp-header'], schema] if schema.is_a?(Hash) && schema.key?('x-mcp-header')
        end
      end
    end
  end
end
