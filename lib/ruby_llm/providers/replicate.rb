# frozen_string_literal: true

module RubyLLM
  module Providers
    # Replicate API integration
    class Replicate < Provider
      include Replicate::Capabilities
      include Replicate::Images
      include Replicate::Models

      def api_base
        'https://api.replicate.com'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.replicate_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      class << self
        def capabilities
          Replicate::Capabilities
        end

        def configuration_requirements
          %i[replicate_api_key]
        end
      end
    end
  end
end
