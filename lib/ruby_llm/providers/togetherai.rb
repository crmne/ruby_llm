# frozen_string_literal: true

module RubyLLM
  module Providers
    # Together.ai API integration.
    class TogetherAI < Provider
      include TogetherAI::Chat
      include TogetherAI::Models

      def api_base
        'https://api.together.xyz/v1'
      end

      def headers
        headers_hash = { 'Content-Type' => 'application/json' }

        if @config.togetherai_api_key && !@config.togetherai_api_key.empty?
          headers_hash['Authorization'] = "Bearer #{@config.togetherai_api_key}"
        end

        headers_hash
      end

      class << self
        def capabilities
          TogetherAI::Capabilities
        end

        def configuration_requirements
          %i[togetherai_api_key]
        end
      end
    end
  end
end
