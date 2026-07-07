# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure < Provider
      # Azure's dialect of the Chat Completions API. Endpoints depend on how
      # the configured api_base is shaped (deployment, resource, or openai/v1).
      class ChatCompletions < Protocols::ChatCompletions
        include Azure::Chat
        include Azure::Embeddings
        include Azure::Media
        include Azure::Models

        def azure_endpoint(kind)
          parts = azure_base_parts

          case kind
          when :chat
            chat_endpoint(parts)
          when :embeddings
            embeddings_endpoint(parts)
          when :models
            models_endpoint(parts)
          else
            raise ArgumentError, "Unknown Azure endpoint kind: #{kind.inspect}"
          end
        end

        private

        def azure_base_parts
          @provider.azure_base_parts
        end

        def chat_endpoint(parts)
          case parts[:mode]
          when :chat_endpoint
            ''
          when :deployment_base
            with_api_version('chat/completions', parts[:version] || Azure::DEFAULT_CHAT_API_VERSION)
          when :openai_v1_base
            with_api_version('chat/completions', parts[:version])
          else
            with_api_version('models/chat/completions', parts[:version] || Azure::DEFAULT_CHAT_API_VERSION)
          end
        end

        def embeddings_endpoint(parts)
          case parts[:mode]
          when :deployment_base, :openai_v1_base
            with_api_version('embeddings', parts[:version])
          else
            "#{parts[:root]}/openai/v1/embeddings"
          end
        end

        def models_endpoint(parts)
          case parts[:mode]
          when :openai_v1_base
            with_api_version('models', parts[:version] || Azure::DEFAULT_MODELS_API_VERSION)
          else
            "#{parts[:root]}/openai/v1/models?api-version=#{parts[:version] || Azure::DEFAULT_MODELS_API_VERSION}"
          end
        end

        def with_api_version(path, version)
          return path unless version

          separator = path.include?('?') ? '&' : '?'
          "#{path}#{separator}api-version=#{version}"
        end
      end
    end
  end
end
