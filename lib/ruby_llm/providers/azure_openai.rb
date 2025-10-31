# frozen_string_literal: true

module RubyLLM
  module Providers
    # Azure OpenAI API integration. Derived from OpenAI integration to support
    # OpenAI capabilities via Microsoft Azure endpoints.
    class AzureOpenAI < OpenAI
      # extend AzureOpenAI::Chat
      # extend AzureOpenAI::Streaming
      extend AzureOpenAI::Models

      def api_base
        # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
        "#{@config.azure_openai_api_base}/openai"
      end

      def completion_url
        # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
        "deployments/#{@model_id}/chat/completions?api-version=#{@config.azure_openai_api_version}"
      end

      def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists
        # Hold model_id in instance variable for use in completion_url and stream_url
        # It would be way better if `model` was passed to those URL methods; but ...
        @model_id = model.id.start_with?('azure-') ? model.id.delete_prefix('azure-') : model.id
        super
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.azure_openai_api_key}"
        }.compact
      end

      def capabilities
        OpenAI::Capabilities
      end

      def slug
        'azure_openai'
      end

      def configuration_requirements
        %i[azure_openai_api_key azure_openai_api_base azure_openai_api_version]
      end

      def local?
        false
      end
    end
  end
end
