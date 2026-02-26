# frozen_string_literal: true

module RubyLLM
  module Providers
    # Voyage AI API integration for embeddings.
    class VoyageAI < Provider
      include VoyageAI::Embeddings
      include VoyageAI::Models

      def api_base
        @config.voyage_api_base || 'https://ai.mongodb.com/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.voyage_api_key}"
        }
      end

      class << self
        def capabilities
          VoyageAI::Capabilities
        end

        def configuration_requirements
          %i[voyage_api_key]
        end
      end
    end
  end
end
