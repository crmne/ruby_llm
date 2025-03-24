# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Handles conversion of schema formats to OpenAI-specific formats
      module Schema
        module_function

        # Convert a schema to OpenAI's response_format format
        #
        # @param format [Class, Hash, String] The format specification
        # @return [Hash] An OpenAI-compatible schema
        def convert(format)
          schema = SchemaConverter.extract_schema(format)

          # Return a structure compatible with OpenAI's response_format parameter
          # https://platform.openai.com/docs/guides/structured-outputs?api-mode=responses
          {
            type: "json_schema",
            schema: schema,
            strict: true
          }
        end
      end
    end
  end
end