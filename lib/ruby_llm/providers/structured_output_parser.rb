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
          raise InvalidStructuredOutput, "Failed to parse JSON from model response: #{e.message}" if raise_on_error

          RubyLLM.logger.warn("Failed to parse JSON from model response: #{e.message}")
          content
        end
      end

      # Cleans markdown code blocks from text
      # @param text [String] The text to clean
      # @return [String] The cleaned text
      def clean_markdown_code_blocks(text)
        return text if text.nil? || text.empty?

        # Extract content between markdown code blocks with newlines
        if text =~ /```(?:json)?.*?\n(.*?)\n\s*```/m
          # If we can find a markdown block, extract just the content
          return ::Regexp.last_match(1).strip
        end

        # Handle cases where there are no newlines
        return ::Regexp.last_match(1).strip if text =~ /```(?:json)?(.*?)```/m

        # No markdown detected, return original
        text
      end

      # Checks if the text appears to be a JSON object
      # @param text [String] The text to check
      # @return [Boolean] True if the text appears to be a JSON object
      def json_object?(text)
        return false unless text.is_a?(String)

        cleaned = text.strip

        # Simple check for JSON object format
        return true if cleaned.start_with?('{') && cleaned.end_with?('}')

        # Try to parse as a quick validation (but don't do this for large texts)
        if cleaned.length < 10_000
          begin
            JSON.parse(cleaned)
            return true
          rescue JSON::ParserError
            # Not valid JSON - fall through
          end
        end

        false
      end
    end
  end
end
