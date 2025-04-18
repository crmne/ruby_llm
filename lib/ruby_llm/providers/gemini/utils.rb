# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Shared utility methods for Gemini provider
      module Utils
        # Extracts model ID from response data
        # @param data [Hash] The response data
        # @param response [Faraday::Response, nil] The full Faraday response (optional)
        # @return [String] The model ID
        def extract_model_id(data, response = nil)
          # First try to get from modelVersion directly
          return data['modelVersion'] if data['modelVersion']

          # Fall back to parsing from URL if response is provided
          return response.env.url.path.split('/')[3].split(':')[0] if response&.env&.url

          # Final fallback - just return a generic identifier
          'gemini'
        end
      end
    end
  end
end
