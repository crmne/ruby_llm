# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama API integration.
    class Ollama < Provider
      # Ollama's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Ollama::Chat
        include Ollama::Media
        include Ollama::Models
      end

      protocol :chat_completions, ChatCompletions

      def api_base
        @config.ollama_api_base
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
