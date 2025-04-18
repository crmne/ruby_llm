# frozen_string_literal: true

module RubyLLM
  module Providers
    # Provides shared utilities for parsing structured output
    # Used by various providers to handle JSON parsing with consistent behavior
    module StructuredOutputParser
      # Parses structured output based on the response content
      # @param content [String] The content to parse
      # @param raise_on_error [Boolean] Whether to raise errors (true) or just log them (false)
      # @return [Hash, String] The parsed JSON or the original content if parsing fails
      def parse_structured_output(content, raise_on_error: true)
        return content if content.nil? || content.empty?
        
        begin
          # First, clean any markdown code blocks
          json_text = clean_markdown_code_blocks(content)
          
          # Then parse if it looks like valid JSON
          if json_object?(json_text)
            JSON.parse(json_text)
          else
            content
          end
        rescue JSON::ParserError => e
          if raise_on_error
            raise InvalidStructuredOutput, "Failed to parse JSON from model response: #{e.message}"
          else
            RubyLLM.logger.warn("Failed to parse JSON from model response: #{e.message}")
            content
          end
        end
      end
      
      # Cleans markdown code blocks from text
      # @param text [String] The text to clean
      # @return [String] The cleaned text
      def clean_markdown_code_blocks(text)
        return text unless text.match?(/```(?:json)?\s*\n/)
        
        text.gsub(/```(?:json)?\s*\n/, '')
            .gsub(/\n\s*```\s*$/, '')
      end
      
      # Checks if the text appears to be a JSON object
      # @param text [String] The text to check
      # @return [Boolean] True if the text appears to be a JSON object
      def json_object?(text)
        text.strip.start_with?('{') && text.strip.end_with?('}')
      end
    end
  end
end