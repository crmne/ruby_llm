# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama API integration.
    class Ollama < OpenAI
      include Ollama::Chat
      include Ollama::Media

      def api_base
        @config.ollama_api_base
      end

      def headers
        {}
      end

      # Ollama doesn't support batch requests yet
      def render_payload_for_batch_request(_messages, tools:, temperature:, model:, params: {}, schema: nil) # rubocop:disable Metrics/ParameterLists
        raise NotImplementedError, 'Ollama does not support batch requests. ' \
                                   'Batch request generation is not available for this provider.'
      end

      class << self
        def configuration_requirements
          %i[ollama_api_base]
        end

        def local?
          true
        end
      end
    end
  end
end
