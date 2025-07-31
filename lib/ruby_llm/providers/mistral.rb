# frozen_string_literal: true

module RubyLLM
  module Providers
    # Mistral API integration.
    module Mistral
      extend OpenAI
      extend Mistral::Chat
      extend Mistral::Models
      extend Mistral::Embeddings

      module_function

      def api_base(_config)
        'https://api.mistral.ai/v1'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.mistral_api_key}"
        }
      end

      def capabilities
        Mistral::Capabilities
      end

      def slug
        'mistral'
      end

      def configuration_requirements
        %i[mistral_api_key]
      end
    end
  end
end
