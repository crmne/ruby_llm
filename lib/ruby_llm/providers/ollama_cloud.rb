# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama Cloud API integration.
    class OllamaCloud < Provider
      # Ollama Cloud's dialect of the Chat Completions API.
      class ChatCompletions < Ollama::ChatCompletions
        include OllamaCloud::Models
      end

      # Ollama Cloud's dialect of the System One API for decision models such as Clef.
      class SystemOne < Ollama::SystemOne
      end

      protocol :chat_completions, ChatCompletions
      protocol :system_one, SystemOne

      def api_base
        @config.ollama_cloud_api_base || 'https://ollama.com/v1'
      end

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= :system_one if operation == :judge
        super
      end

      def headers
        { 'Authorization' => "Bearer #{@config.ollama_cloud_api_key}" }
      end

      class << self
        def configuration_options
          %i[ollama_cloud_api_key ollama_cloud_api_base]
        end

        def configuration_requirements
          %i[ollama_cloud_api_key]
        end

        # Returns +true+: Ollama retires cloud models faster than the
        # registry tracks them, so model ids are accepted as given. Call
        # RubyLLM.models.refresh to pull the live catalog.
        def assume_models_exist?
          true
        end
      end
    end
  end
end
