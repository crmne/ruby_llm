# frozen_string_literal: true

module RubyLLM
  module Providers
    # Azure AI Foundry / OpenAI-compatible API integration.
    class Azure < Provider
      protocol :chat_completions, Azure::ChatCompletions
      files Azure::Files

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

      def azure_openai_v1_base
        parts = azure_base_parts
        if parts[:mode] == :openai_v1_base
          parts[:path_base]
        else
          "#{parts[:root]}/openai/v1"
        end
      end

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
            path_base: path_base,
            root: azure_host_root(path_base),
            mode: mode,
            version: version
          }
        end
      end

      class << self
        def configuration_options
          %i[azure_api_base azure_api_key azure_ai_auth_token]
        end

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

      def azure_host_root(base_without_query)
        base_without_query.sub(%r{/(models|openai)/.*\z}, '').sub(%r{/+\z}, '')
      end
    end
  end
end
