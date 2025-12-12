# frozen_string_literal: true

module RubyLLM
  module Providers
    class AzureOpenAI
      # Chat methods of the Azure OpenAI API integration
      module Chat
        def completion_url
          # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
          "deployments/#{@model_id}/chat/completions?api-version=#{@config.azure_openai_api_version}"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil)
          # Hold model_id in instance variable for use in completion_url and stream_url
          @model_id = model.id
          super
        end
      end
    end
  end
end
