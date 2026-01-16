# frozen_string_literal: true

module RubyLLM
  module Providers
    # xAI API integration
    class XAI < OpenAI
      include XAI::Chat
      include XAI::Models

      def api_base
        'https://api.x.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.xai_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      class << self
        def configuration_requirements
          %i[xai_api_key]
        end
      end
    end
  end
end
