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
      extend Ollama::Media
      extend Ollama::Tools

      module_function

      def api_base(config)
        # no default since this is the only configuration for this provider,
        # so it must be provided deliberately
        config.ollama_api_base_url
      end

      def headers(config)
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
