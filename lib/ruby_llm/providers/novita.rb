# frozen_string_literal: true

module RubyLLM
  module Providers
    # Novita API integration (OpenAI-compatible).
    class Novita < OpenAI
      include Novita::Chat
      include Novita::Models

      def api_base
        @config.novita_api_base || 'https://api.novita.ai/openai'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.novita_api_key}"
        }.compact
      end

      class << self
        def configuration_options
          %i[novita_api_key novita_api_base]
        end

        def configuration_requirements
          %i[novita_api_key]
        end
      end
    end
  end
end
