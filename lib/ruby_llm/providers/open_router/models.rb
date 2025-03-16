# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Models module for the OpenRouter API integration
      module Models
        module_function

        def list_models
          response = get('models')
          parse_models_response(response)
        end

        def parse_models_response(response)
          data = response.body
          return [] if data.empty?

          data['data'].map do |model_data|
            ModelInfo.new(
              id: model_data['id'],
              name: model_data['name'],
              provider: 'open_router',
              capabilities: parse_capabilities(model_data),
              context_window: model_data['context_length'],
              pricing: {
                input: model_data['pricing']['input'],
                output: model_data['pricing']['output']
              }
            )
          end
        end

        def parse_capabilities(model_data)
          {
            chat: true,
            embeddings: model_data['type'] == 'embeddings',
            images: false,
            streaming: true,
            tools: model_data['supports_tools'] || false
          }
        end

        def translate_model_id(model)
          # OpenRouter uses model IDs in the format: provider/model
          # Example: anthropic/claude-3-opus-20240229
          model
        end
      end
    end
  end
end 