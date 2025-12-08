# frozen_string_literal: true

module RubyLLM
  module Providers
    # Deepgram API integration for audio transcription.
    class Deepgram < Provider
      include Deepgram::Models
      include Deepgram::Transcription

      def api_base
        @config.deepgram_api_base || 'https://api.deepgram.com/v1'
      end

      def headers
        {
          'Authorization' => "Token #{@config.deepgram_api_key}"
        }
      end

      class << self
        def capabilities
          Deepgram::Capabilities
        end

        def configuration_requirements
          %i[deepgram_api_key]
        end
      end
    end
  end
end
