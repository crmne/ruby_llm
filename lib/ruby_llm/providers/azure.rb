# frozen_string_literal: true

module RubyLLM
  module Providers
    # Azure AI Foundry / OpenAI-compatible API integration.
    class Azure < OpenAI
      AZURE_DEFAULT_CHAT_API_VERSION = '2024-05-01-preview'
      AZURE_DEFAULT_MODELS_API_VERSION = 'preview'

      include Azure::Chat
      include Azure::Embeddings
      include Azure::Media
      include Azure::Models

      def api_base
        @config.azure_api_base
      end

      def headers
        if @config.azure_api_key
          { 'api-key' => @config.azure_api_key }
        else
          { 'Authorization' => "Bearer #{@config.azure_ai_auth_token}" }
        end
      end

      def configured?
        self.class.configured?(@config)
      end

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

      class << self
        def configuration_requirements
          %i[azure_api_base]
        end

        def configured?(config)
          config.azure_api_base && (config.azure_api_key || config.azure_ai_auth_token)
        end

        # Azure works with deployment names, instead of model names
        def assume_models_exist?
          true
        end
      end

      def ensure_configured!
        missing = []
        missing << :azure_api_base unless @config.azure_api_base
        if @config.azure_api_key.nil? && @config.azure_ai_auth_token.nil?
          missing << 'azure_api_key or azure_ai_auth_token'
        end
        return if missing.empty?

        raise ConfigurationError,
              "Missing configuration for Azure: #{missing.join(', ')}"
      end

      private

      def azure_base_parts
        @azure_base_parts ||= begin
          raw_base = api_base.to_s.sub(%r{/+\z}, '')
          version = raw_base[/[?&]api-version=([^&]+)/i, 1]
          path_base = raw_base.sub(/\?.*\z/, '')

          mode = if path_base.include?('/chat/completions')
                   :chat_endpoint
                 elsif path_base.include?('/openai/deployments/')
                   :deployment_base
                 elsif path_base.include?('/openai/v1')
                   :openai_v1_base
                 else
                   :resource_base
                 end

          {
            raw_base: raw_base,
            path_base: path_base,
            root: azure_host_root(path_base),
            mode: mode,
            version: version
          }
        end
      end

      def chat_endpoint(parts)
        case parts[:mode]
        when :chat_endpoint
          ''
        when :deployment_base
          with_api_version('chat/completions', parts[:version] || AZURE_DEFAULT_CHAT_API_VERSION)
        when :openai_v1_base
          with_api_version('chat/completions', parts[:version])
        else
          with_api_version('models/chat/completions', parts[:version] || AZURE_DEFAULT_CHAT_API_VERSION)
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
          with_api_version('models', parts[:version] || AZURE_DEFAULT_MODELS_API_VERSION)
        else
          "#{parts[:root]}/openai/v1/models?api-version=#{parts[:version] || AZURE_DEFAULT_MODELS_API_VERSION}"
        end
      end

      def with_api_version(path, version)
        return path unless version

        separator = path.include?('?') ? '&' : '?'
        "#{path}#{separator}api-version=#{version}"
      end

      def azure_host_root(base_without_query)
        base_without_query.sub(%r{/(models|openai)/.*\z}, '').sub(%r{/+\z}, '')
      end
    end
  end
end
