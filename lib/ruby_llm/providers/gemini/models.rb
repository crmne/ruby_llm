# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Models methods for the Gemini API integration
      module Models
        # Methods needed by Provider - must be public
        def models_url
          'models'
        end

        private

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          (response.body['models'] || []).map do |model|
            # Extract model ID without "models/" prefix
            model_id = model['name'].gsub('models/', '')

            ModelInfo.new(
              id: model_id,
              created_at: nil,
              display_name: model['displayName'],
              provider: slug,
              type: capabilities.model_type(model_id),
              family: capabilities.model_family(model_id),
              metadata: {
                version: model['version'],
                description: model['description'],
                input_token_limit: model['inputTokenLimit'],
                output_token_limit: model['outputTokenLimit'],
                supported_generation_methods: model['supportedGenerationMethods']
              },
              context_window: model['inputTokenLimit'] || capabilities.context_window_for(model_id),
              max_tokens: model['outputTokenLimit'] || capabilities.max_tokens_for(model_id),
              supports_vision: capabilities.supports_vision?(model_id),
              supports_functions: capabilities.supports_functions?(model_id),
              supports_json_mode: capabilities.supports_json_mode?(model_id),
              input_price_per_million: capabilities.input_price_for(model_id),
              output_price_per_million: capabilities.output_price_for(model_id)
            )
          end
        end
      end
    end
  end
end
