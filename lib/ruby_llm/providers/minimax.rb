# frozen_string_literal: true

module RubyLLM
  module Providers
    # Direct MiniMax speech API integration.
    class MiniMax < Provider
      MODELS = %w[
        speech-2.8-hd speech-2.8-turbo speech-2.6-hd speech-2.6-turbo
        speech-02-hd speech-02-turbo speech-01-hd speech-01-turbo
      ].freeze

      class SpeechProtocol < Protocol
        include MiniMax::Speech
      end

      protocol :speech, SpeechProtocol

      def api_base
        @config.minimax_api_base || 'https://api.minimax.io/v1'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.minimax_api_key}" }
      end

      def synthesize_async(input, model: MODELS.first, voice: nil, provider_options: {})
        default_protocol.new(self, model).send(:synthesize_async, input, model:, voice:, provider_options:)
      end

      def speech_task(task_id)
        default_protocol.new(self).send(:speech_task, task_id)
      end

      def speech_websocket_url
        api_base.sub(/\Ahttp/, 'ws').sub(%r{/v1/?\z}, '/ws/v1/t2a_v2')
      end

      class << self
        def assume_models_exist?
          true
        end

        def configuration_options
          %i[minimax_api_key minimax_api_base]
        end

        def configuration_requirements
          %i[minimax_api_key]
        end
      end
    end
  end
end
