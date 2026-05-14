# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama API integration.
    class Ollama < OpenAI
      include Ollama::Chat
      include Ollama::Media
      include Ollama::Models

      # Ollama exposes two API surfaces:
      #   - Native API at /api/* (different request/response format)
      #   - OpenAI-compatible API at /v1/* (same format as OpenAI)
      # Since this provider inherits from OpenAI, we use the /v1 endpoint
      # so all OpenAI logic (chat, models, schemas) works without changes.
      def api_base
        base = @config.ollama_api_base.to_s.chomp('/')
        base.end_with?('/v1') ? base : "#{base}/v1"
      end

      def headers
        return {} unless @config.ollama_api_key

        { 'Authorization' => "Bearer #{@config.ollama_api_key}" }
      end

      class << self
        def configuration_options
          %i[ollama_api_base ollama_api_key]
        end

        def configuration_requirements
          %i[ollama_api_base]
        end

        def local?
          true
        end

        def capabilities
          Ollama::Capabilities
        end
      end
    end
  end
end
