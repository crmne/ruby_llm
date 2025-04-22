# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    module OpenRouter
      extend OpenAI
      extend OpenRouter::Models

      module_function

      def api_base(_config)
        'https://openrouter.ai/api/v1'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.openrouter_api_key}"
        }
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
