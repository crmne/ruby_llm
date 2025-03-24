# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Handles conversion of schema formats to Anthropic-specific formats
      module Schema
        module_function

        # Convert a schema to Anthropic's format parameter
        #
        # @param format [Class, Hash, String] The format specification
        # @return [Hash] An Anthropic-compatible schema configuration with instructions
        def convert(format)
          # Set the basic format parameter
          result = {
            format: "json_object"
          }

          # Extract the schema to add as instructions
          schema = SchemaConverter.extract_schema(format)

          # Create instructions with the schema
          result[:system_instruction] = generate_schema_instructions(schema)

          result
        end

        # Generate instructions for Claude to follow the schema
        #
        # @param schema [Hash] The JSON schema
        # @return [String] Instructions for Claude to follow
        def generate_schema_instructions(schema)
          schema_json = JSON.pretty_generate(schema)

          <<~INSTRUCTIONS
            You must respond with a valid JSON object that strictly adheres to the following JSON schema:

            ```json
            #{schema_json}
            ```

            Do not include any explanations, preambles, or additional text in your response.
            Your entire response must be a single valid JSON object that follows the schema exactly.
            Make sure all required fields are included, and don't add any fields not specified in the schema.
          INSTRUCTIONS
        end
      end
    end
  end
end