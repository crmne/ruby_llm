# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenRouter
      # Models methods of the OpenRouter API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          (response.body['data'] || []).map do |model|
            ModelInfo.new(
              id: model['id'],
              created_at: model['created'] ? Time.at(model['created']) : nil,
              display_name: model['name'],
              provider: slug,
              type: determine_model_type(model),
              family: capabilities.model_family(model['id']),
              metadata: {
                object: model['object'],
                description: model['description'],
                architecture: model['architecture'],
                pricing: model['pricing'],
                top_provider: model['top_provider']
              },
              context_window: model['context_length'],
              max_tokens: model.dig('top_provider', 'max_completion_tokens'),
              supports_vision: model.dig('architecture', 'input_modalities')&.include?('image'),
              supports_functions: true, # assuming all models support functions
              supports_json_mode: true, # assuming all models support JSON mode
              input_price_per_million: (model.dig('pricing', 'prompt').to_f * 1_000_000),
              output_price_per_million: (model.dig('pricing', 'completion').to_f * 1_000_000)
            )
          end
        end

        private

        def determine_model_type(model)
          model.dig('architecture', 'output_modalities')&.include?('text') ? 'chat' : 'other'
        end
      end
    end
  end
end
