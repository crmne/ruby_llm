# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama API integration.
    class Ollama < Provider
      # Ollama's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Ollama::Chat
        include Ollama::Embeddings
        include Ollama::Media
        include Ollama::Models
        include Ollama::Speech
      end

      # Ollama's dialect of the System One API for decision models such as Clef.
      class SystemOne < Protocols::SystemOne
        include Ollama::Judgments
      end

      # Ollama's stateless Responses API, which serves manual compaction.
      class Responses < Protocols::Responses
        include Protocols::Responses::Compaction

        def render_image(image, image_url: image.for_llm, **)
          super
        end
      end

      protocol :chat_completions, ChatCompletions
      protocol :system_one, SystemOne
      protocol :responses, Responses

      def api_base
        configured_api_base(:ollama_api_base, example: 'http://localhost:11434/v1', endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= :system_one if operation == :judge
        super
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
      end
    end
  end
end
