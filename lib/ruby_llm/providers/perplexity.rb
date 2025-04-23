# frozen_string_literal: true

module RubyLLM
  module Providers
    # Perplexity API integration. Handles chat completion, streaming,
    # and Perplexity's unique features like citations.
    module Perplexity
      extend OpenAI
      extend Perplexity::Chat
      extend Perplexity::Models

      module_function

      def api_base(_config)
        'https://api.perplexity.ai'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.perplexity_api_key}",
          'Content-Type'  => 'application/json'
        }
      end

      def capabilities
        Perplexity::Capabilities
      end

      def slug
        'perplexity'
      end

      def configuration_requirements
        %i[perplexity_api_key]
      end
    end
  end
end
