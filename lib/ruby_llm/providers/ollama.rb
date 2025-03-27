# frozen_string_literal: true

module RubyLLM
  module Providers
    # Native Ollama API implementation
    module Ollama
      extend Provider
      extend Ollama::Chat
      extend Ollama::Embeddings
      extend Ollama::Models
      extend Ollama::Streaming

      module_function

      def api_base
        RubyLLM.config.ollama_api_base_url
      end

      def headers
        {}
      end

      def capabilities
        Ollama::Capabilities
      end

      def slug
        'ollama'
      end

      def configuration_requirements
        %i[ollama_api_base_url]
      end

      def parse_error(response)
        return if response.body.empty?

        body = try_parse_json(response.body)
        body['error']
      end
    end
  end
end
