# frozen_string_literal: true

module RubyLLM
  module Providers
    # Native Gemini API implementation
    class Gemini < Provider
      protocol :gemini, Protocols::Gemini, batches: Protocols::Gemini::Batches
      protocol :interactions, Protocols::Interactions
      protocol :live_transcription, Protocols::Gemini::LiveTranscription
      protocol :files, Protocols::Gemini::Files

      def protocol_for(model, operation: nil, **)
        return protocols[:interactions] if operation == :transcribe && model.id == 'gemini-3.5-transcribe'
        return protocols[:live_transcription] if operation == :transcribe && model.id == 'gemini-3.5-transcribe-live'

        super
      end

      def api_base
        @config.gemini_api_base || 'https://generativelanguage.googleapis.com/v1beta'
      end

      def headers
        {
          'x-goog-api-key' => @config.gemini_api_key
        }
      end

      def batch_cost_multiplier(component:, **)
        %i[cache_read cache_write].include?(component) ? 1 : 0.5
      end

      class << self
        def capabilities
          Gemini::Capabilities
        end

        def configuration_options
          %i[gemini_api_key gemini_api_base]
        end

        def configuration_requirements
          %i[gemini_api_key]
        end
      end
    end
  end
end
