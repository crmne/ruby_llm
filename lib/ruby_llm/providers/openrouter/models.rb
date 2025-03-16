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
              type: 'chat',
              family: model['id'].split('/').first,
              metadata: {
                tokenizer: model['architecture']['tokenizer'],
                instruct_type: model['architecture']['instruct_type'],
                moderated: model['top_provider']['is_moderated']
              },
              context_window: model['top_provider']['context_length'],
              max_tokens: model['top_provider']['max_completion_tokens'],
              supports_vision: model['architecture']['modality'].split('->').first.include?('image'),
              supports_functions: capabilities.supports_functions?(model['id']),
              supports_json_mode: capabilities.supports_json_mode?(model['id']),
              input_price_per_million: model['pricing']['prompt'].to_i * 1_000_000,
              output_price_per_million: model['pricing']['completion'].to_i * 1_000_000
            )
          end
        end
      end
    end
  end
end
