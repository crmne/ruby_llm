# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Handles error parsing for Mistral API responses
      module Error
        module_function

        def parse_error(response)
          return nil unless response.body["error"]

          error_message = response.body.dig("error", "message")
          
          # Format the error message to be more user-friendly
          formatted_message = format_error_message(error_message)
          
          RubyLLM::Error.new(response, formatted_message)
        end

        def format_error_message(message)
          # Ensure the message starts with a capital letter
          message = message.to_s.strip
          message = message[0].upcase + message[1..-1] if message.length > 0
          
          # Handle specific error message formats
          if message.include?('Input should be a valid')
            "Invalid message format: The message content is not properly formatted"
          elsif message.include?('input') && message.include?('valid')
            "Invalid message format: The message content is not properly formatted"
          else
            # Replace common error patterns with more user-friendly messages
            message = message.gsub(/invalid request/i, "Invalid request")
            message = message.gsub(/invalid message format/i, "Invalid message format")
            message = message.gsub(/invalid content/i, "Invalid message content")
            message
          end
        end
      end
    end
  end
end 