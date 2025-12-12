# frozen_string_literal: true

module RubyLLM
  module Providers
    # Azure OpenAI API integration. Derived from OpenAI integration to support
    # OpenAI capabilities via Microsoft Azure endpoints.
    class AzureOpenAI < Provider
      # Include OpenAI modules first for base functionality
      include OpenAI::Chat
      include OpenAI::Embeddings
      include OpenAI::Tools
      include OpenAI::Media
      include OpenAI::Streaming
      include OpenAI::Models

      # Then include Azure overrides
      include AzureOpenAI::Chat
      include AzureOpenAI::Embeddings
      include AzureOpenAI::Streaming
      include AzureOpenAI::Models

      def api_base
        # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
        "#{@config.azure_openai_api_base}/openai"
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.azure_openai_api_key}"
        }.compact
      end

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def slug
          'azure_openai'
        end

        def configuration_requirements
          %i[azure_openai_api_key azure_openai_api_base azure_openai_api_version]
        end
      end
    end
  end
end
