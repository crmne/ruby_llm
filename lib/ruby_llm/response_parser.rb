# frozen_string_literal: true

require 'ostruct'
require 'json'

module RubyLLM
  # Responsible for parsing LLM responses into structured objects.
  # Supports various formats (JSON, XML, custom) and allows users to
  # register their own custom parsers.
  module ResponseParser
    class Error < RubyLLM::Error; end
    class InvalidSchemaError < Error; end
    class ParsingError < Error; end

    # Registry for custom format parsers
    @parsers = {}

    class << self
      # Parse an LLM response according to the specified format
      #
      # @param response [Message] The LLM response message to parse
      # @param format [Class, Hash, String, Symbol, nil] The format specification
      # @return [Object] The parsed response as an appropriate Ruby object
      def parse(response, format = nil)
        # Use text parser by default if no format specified
        format ||= :text

        # Determine parser based on format type
        parser = parser_for(format)

        # Return original response if no parser is found (failsafe)
        return response unless parser

        begin
          parsed_result = parser.parse(response, format)

          # If the parser returned a non-Message object, wrap it in a Message
          if !parsed_result.is_a?(Message) && parsed_result.is_a?(Object)
            # Preserve original message attributes but replace content with parsed result
            Message.new(
              role: response.role,
              tool_calls: response.tool_calls,
              tool_call_id: response.tool_call_id,
              input_tokens: response.input_tokens,
              output_tokens: response.output_tokens,
              model_id: response.model_id,
              content: parsed_result
            )
          else
            parsed_result
          end
        rescue => e
          # In case of parsing error, log the error and return the original response
          RubyLLM.logger.error("Error parsing response: #{e.message}")
          response
        end
      end

      # Register a custom parser for a specific format type
      #
      # @param format_type [Symbol] The format type identifier
      # @param parser [Object] The parser to use for this format type
      def register(format_type, parser)
        @parsers[format_type.to_sym] = parser
      end

      # Get all registered parsers
      #
      # @return [Hash] The registered parsers
      def parsers
        @parsers
      end

      # Retrieve the appropriate parser for the given format
      #
      # @param format [Object] The format specification
      # @return [Object] The parser to use
      def parser_for(format)
        if format.is_a?(Symbol) && @parsers.key?(format)
          @parsers[format]
        elsif format.is_a?(Class) && format.respond_to?(:json_schema)
          @parsers[:json]
        elsif format.is_a?(Hash) && (format[:type] == 'object' || format[:properties])
          @parsers[:json]
        elsif format.is_a?(String) && format.strip.start_with?('{')
          @parsers[:json]
        else
          # Default to text parser if no match
          @parsers[:text]
        end
      end
    end

    # Text parser that does no processing (default)
    module TextParser
      # Returns the response unchanged
      #
      # @param response [Message] The LLM response message
      # @param _format [Object] Ignored for text parser
      # @return [Message] The original message unchanged
      def self.parse(response, _format = nil)
        response
      end
    end

    # Parser for JSON-formatted responses
    module JsonParser
      # Parse a response into a structured Ruby object based on JSON schema
      #
      # @param response [Message] The LLM response message
      # @param format [Class, Hash, String] The format specification
      # @return [Object] A Ruby object matching the schema
      def self.parse(response, format)
        return response unless response.content.is_a?(String)

        # Extract JSON data from response
        json_data = JSON.parse(response.content)

        if format.is_a?(Class) && format.respond_to?(:json_schema)
          # Create an instance of the class and populate its properties
          instantiate_from_schema(format, json_data)
        else
          # Return an OpenStruct for generic JSON
          deep_to_ostruct(json_data)
        end
      rescue JSON::ParserError => e
        raise ParsingError, "Failed to parse JSON response: #{e.message}"
      end

      # Create an instance of a class based on JSON data
      #
      # @param klass [Class] The class to instantiate
      # @param data [Hash] The data to populate the instance with
      # @return [Object] An instance of klass populated with data
      def self.instantiate_from_schema(klass, data)
        instance = klass.new

        data.each do |key, value|
          setter = "#{key}="
          if instance.respond_to?(setter)
            instance.send(setter, value)
          end
        end

        instance
      end

      # Convert a Hash to an OpenStruct, recursively handling nested structures
      #
      # @param obj [Hash, Array, Object] The object to convert
      # @return [OpenStruct, Array, Object] The converted object
      def self.deep_to_ostruct(obj)
        case obj
        when Hash
          OpenStruct.new(
            obj.transform_values { |v| deep_to_ostruct(v) }
          )
        when Array
          obj.map { |item| deep_to_ostruct(item) }
        else
          obj
        end
      end
    end

    # Example XML Parser (simple implementation)
    module XmlParser
      # Extract content from XML responses
      #
      # @param response [Message] The LLM response message
      # @param format [Hash, Symbol] Format options for XML parsing
      # @return [Object] Extracted content based on format options
      def self.parse(response, format)
        return response unless response.content.is_a?(String)

        content = response.content

        # If format includes a tag to extract
        if format.is_a?(Hash) && format[:tag]
          tag = format[:tag]
          # Simple regex-based extraction - for production use a proper XML parser
          match = content.match(/<#{tag}>(.*?)<\/#{tag}>/m)
          return match[1] if match
        end

        # Return original content if no extraction happened
        content
      end
    end

    # Register default parsers
    register(:json, JsonParser)
    register(:text, TextParser)
    register(:xml, XmlParser)
  end
end