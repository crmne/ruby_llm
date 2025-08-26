# frozen_string_literal: true

module RubyLLM
  module Providers
    # xAI API integration
    class XAI < OpenAI
      include XAI::Chat

      def api_base
        'https://api.x.ai/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.xai_api_key}",
          'Content-Type' => 'application/json'
        }
      end

      # xAI uses a different error format than OpenAI
      # {"code": "...", "error": "..."}
      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash then body['error']
        when Array then body.map { |part| part['error'] }.join('. ')
        else body
        end
      end

      class << self
        def configuration_requirements
          %i[xai_api_key]
        end
      end
    end
  end
end
