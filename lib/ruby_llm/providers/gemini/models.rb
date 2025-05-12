# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Models methods for the Gemini API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['models']).map do |model_data|
            # Extract model ID without "models/" prefix
            model_id = model_data['name'].gsub('models/', '')

            ModelInfo.new(
              id: model_id,
              name: model_data['displayName'],
              provider: slug,
              family: capabilities.model_family(model_id),
              created_at: nil, # Gemini API doesn't provide creation date
              context_window: model_data['inputTokenLimit'] || capabilities.context_window_for(model_id),
              max_output_tokens: model_data['outputTokenLimit'] || capabilities.max_tokens_for(model_id),
              modalities: capabilities.modalities_for(model_id),
              capabilities: capabilities.capabilities_for(model_id),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                version: model_data['version'],
                description: model_data['description'],
                supported_generation_methods: model_data['supportedGenerationMethods']
              }
            )
          end
        end
      end
    end
  end
end
