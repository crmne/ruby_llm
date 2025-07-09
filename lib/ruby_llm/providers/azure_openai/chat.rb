# frozen_string_literal: true

module RubyLLM
  module Providers
    module AzureOpenAI
      # Chat methods of the Ollama API integration
      module Chat
        extend OpenAI::Chat

        module_function

        def sync_response(connection, payload)
          # Hold config in instance variable for use in completion_url and stream_url
          @config = connection.config
          super
        end

        def completion_url
          # https://<ENDPOINT>/openai/deployments/<MODEL>/chat/completions?api-version=<APIVERSION>
          "#{@model_id}/chat/completions?api-version=#{@config.azure_openai_api_version}"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false)
          # Hold model_id in instance variable for use in completion_url and stream_url
          @model_id = model
          super
        end
      end
    end
  end
end
