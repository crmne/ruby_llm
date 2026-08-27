# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Models methods of the Azure AI Foundry API integration
      module Models
        def models_url
          azure_endpoint(:models)
        end

        # Azure reports the same id once per region it is offered in, and keeps
        # returning models whose inference deprecation date has passed.
        def parse_list_models_response(response, slug)
          Array(response.body['data'])
            .uniq { |model_data| model_data['id'] }
            .reject { |model_data| azure_inference_retired?(model_data) }
            .map { |model_data| azure_model(model_data, slug) }
        end

        def azure_inference_retired?(model_data)
          retires_at = model_data.dig('deprecation', 'inference')
          retires_at.is_a?(Numeric) && Time.at(retires_at) < Time.now
        end

        def azure_model(model_data, slug)
          Model.new(
            id: model_data['id'],
            name: model_data['id'],
            provider: slug,
            created_at: model_data['created_at'] ? Time.at(model_data['created_at']) : nil,
            modalities: azure_modalities(model_data['capabilities'] || {}),
            metadata: {
              object: model_data['object'],
              lifecycle_status: model_data['lifecycle_status'],
              inference_retires_at: model_data.dig('deprecation', 'inference')
            }.compact
          )
        end

        def azure_modalities(capabilities)
          return { input: ['text'], output: ['embeddings'] } if capabilities['embeddings']

          { input: ['text'], output: ['text'] }
        end
      end
    end
  end
end
