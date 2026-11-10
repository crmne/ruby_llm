# frozen_string_literal: true

module RubyLLM
  module Providers
    # Ollama Cloud API integration.
    class OllamaCloud < Provider
      # Ollama Cloud's dialect of the Chat Completions API.
      class ChatCompletions < Ollama::ChatCompletions
        include OllamaCloud::Models

        abstract :embedding_url, :embedding_media?, :speech_url, :build_audio_file_part, :render_image_payload,
                 :render_moderation_payload
      end

      # Ollama Cloud's dialect of the System One API for decision models such as Clef.
      class SystemOne < Ollama::SystemOne
      end

      protocol :chat_completions, ChatCompletions
      protocol :system_one, SystemOne

      def api_base
        configured_api_base(:ollama_cloud_api_base, 'https://ollama.com/v1', endpoints: Protocols::ChatCompletions::ENDPOINT_PATHS)
      end

      def resolve_protocol(name, model, operation: nil, **options)
        name ||= :system_one if operation == :judge
        super
      end

      def headers
        { 'Authorization' => "Bearer #{@config.ollama_cloud_api_key}" }
      end

      class << self
        def open_telemetry_name # :nodoc:
          'ollama'
        end

        def models_dev_provider_ids # :nodoc:
          %w[ollama-cloud]
        end

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
