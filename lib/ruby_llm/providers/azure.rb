# frozen_string_literal: true

module RubyLLM
  module Providers
    # Azure AI Foundry / OpenAI-compatible API integration.
    class Azure < OpenAI
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
    end
  end
end
