# frozen_string_literal: true

module RubyLLM
  module Providers
    # Cohere API integration.
    class Cohere < Provider
      protocol :cohere, Protocols::Cohere

      def api_base
        @config.cohere_api_base || 'https://api.cohere.com'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.cohere_api_key}"
        }
      end

      class << self
        def capabilities
          Cohere::Capabilities
        end

        def configuration_options
          %i[cohere_api_key cohere_api_base]
        end

        def configuration_requirements
          %i[cohere_api_key]
        end
      end
    end
  end
end
