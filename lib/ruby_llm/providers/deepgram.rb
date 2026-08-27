# frozen_string_literal: true

module RubyLLM
  module Providers
    # Deepgram API integration. Deepgram is a speech company, so this
    # provider covers speech to text and text to speech only. Chat,
    # embeddings, and image generation have no Deepgram endpoint and
    # raise NotImplementedError.
    class Deepgram < Provider
      protocol :deepgram, Protocols::Deepgram

      def api_base
        @config.deepgram_api_base || 'https://api.deepgram.com'
      end

      def headers
        { 'Authorization' => "Token #{@config.deepgram_api_key}" }
      end

      # Deepgram reports failures as an err_msg alongside an err_code, which
      # the generic error parser does not know to look for.
      def parse_error(response)
        body = parse_error_body(response)
        return super unless body.is_a?(Hash)

        body['err_msg'] || super
      end

      class << self
        def configuration_options
          %i[deepgram_api_key deepgram_api_base]
        end

        def configuration_requirements
          %i[deepgram_api_key]
        end
      end
    end
  end
end
