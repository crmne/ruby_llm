# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Models methods of the Ollama API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            Model::Info.new(
              id: model_data['id'],
              name: model_data['id'],
              provider: slug,
              family: 'ollama',
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              modalities: {
                input: %w[text image], # Ollama models don't advertise input modalities, so we assume text and image
                output: ['text'] # Ollama models don't expose output modalities, so we assume text
              },
              capabilities: %w[streaming function_calling structured_output],
              pricing: {}, # Ollama does not provide pricing details
              metadata: {}
            )
          end
        end
      end
    end
  end
end
