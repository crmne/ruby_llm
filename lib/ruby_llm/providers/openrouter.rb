# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenRouter API integration.
    class OpenRouter < OpenAI
      include OpenRouter::Models

      def api_base
        'https://openrouter.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openrouter_api_key}"
        }
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        case body
        when Hash
          parse_error_part_message body
        when Array
          body.map do |part|
            parse_error_part_message part
          end.join('. ')
        else
          body
        end
      end

      private

      def parse_error_part_message(part)
        message = part.dig('error', 'message')
        raw = try_parse_json(part.dig('error', 'metadata', 'raw'))
        return message unless raw.is_a?(Hash)

        raw_message = raw.dig('error', 'message')
        return [message, raw_message].join(' - ') if raw_message

        message
      end

      class << self
        def configuration_requirements
          %i[openrouter_api_key]
        end
      end
    end
  end
end
