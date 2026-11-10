# frozen_string_literal: true

module RubyLLM
  module Providers
    # Integrates Deepgram transcription, speech synthesis, and chat.
    class Deepgram < Provider
      # Deepgram's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Deepgram::Chat
      end

      THINK_BASE = 'https://agent.deepgram.com'
      private_constant :THINK_BASE

      protocol :deepgram, Protocols::Deepgram
      protocol :chat_completions, ChatCompletions

      def api_base
        configured_api_base(:deepgram_api_base, 'https://api.deepgram.com', endpoints: %r{/v1/(?:listen|speak|think)\z})
      end

      # Chat runs on its own host. Speech, transcription, and the model
      # listing stay on the Deepgram protocol.
      def protocol_for(model, operation: nil, **)
        operation ? super : protocols[:chat_completions]
      end

      def think_url # :nodoc:
        "#{(@config.deepgram_api_base || THINK_BASE).chomp('/')}/v1/think"
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
