# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama API integration.
    module Ollama
      extend OpenAI
      extend Ollama::Chat
      extend Ollama::Media

      module_function

      def api_base(config)
        config.ollama_api_base
      end

      def headers(_config)
        {}
      end

      def slug
        'ollama'
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
