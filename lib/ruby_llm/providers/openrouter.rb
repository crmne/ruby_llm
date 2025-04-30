# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    module OpenRouter
      extend OpenAI
      extend OpenRouter::Models
      extend OpenRouter::Media

      module_function

      def api_base(_config)
        'https://openrouter.ai/api/v1'
      end

      # @see https://openrouter.ai/docs/api-reference/overview#headers
      def headers(config)
        {
          'Authorization' => "Bearer #{config.openrouter_api_key}",
          'HTTP-Referer' => config.openrouter_referer, # Optional: Site URL for rankings on openrouter.ai.
          'X-Title' => config.openrouter_title         # Optional: Site title for rankings on openrouter.ai.
        }.compact
      end

      def slug
        'openrouter'
      end

      def configuration_requirements
        %i[openrouter_api_key]
      end
    end
  end
end
