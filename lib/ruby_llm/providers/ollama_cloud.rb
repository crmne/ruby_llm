# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama Cloud API integration using native Ollama API format.
    # Connects to https://ollama.com for cloud-hosted models.
    class OllamaCloud < Provider
      include OllamaCloud::Chat
      include OllamaCloud::Media
      include OllamaCloud::Models
      include OllamaCloud::Embeddings

      def api_base
        @config.ollama_api_base || 'https://ollama.com'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.ollama_api_key}"
        }.compact
      end

      class << self
        def configuration_requirements
          %i[ollama_api_key]
        end

        def local?
          false
        end

        def assume_models_exist?
          true
        end
      end
    end
  end
end
