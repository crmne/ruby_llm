# frozen_string_literal: true

module RubyLLM
  # Provides common schema extraction and conversion utilities.
  # Provider-specific schema conversions are handled by the respective provider modules.
  class SchemaConverter
    class Error < RubyLLM::Error; end
    class InvalidSchemaError < Error; end

    class << self
      # Extract a JSON schema from various formats
      #
      # @param format [Class, Hash, String] The format specification
      # @return [Hash] The extracted JSON schema
      def extract_schema(format)
        if format.is_a?(Class) && format.respond_to?(:json_schema)
          format.json_schema
        elsif format.is_a?(Hash)
          format
        elsif format.is_a?(String)
          begin
            JSON.parse(format, symbolize_names: true)
          rescue JSON::ParserError
            raise InvalidSchemaError, "Invalid JSON schema: #{format}"
          end
        else
          raise InvalidSchemaError, "Unsupported schema format: #{format.class}"
        end
      end
    end
  end
end