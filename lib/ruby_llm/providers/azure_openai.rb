# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration. Handles chat completion, function calling,
    # and OpenAI's unique streaming format. Supports GPT-4, GPT-3.5,
    # and other OpenAI models.
    module AzureOpenAI
      extend OpenAI
      extend AzureOpenAI::Chat

      module_function

      def api_base(config)
        # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
        "#{config.azure_openai_api_base}/openai/deployments"
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.azure_openai_api_key}"
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
