# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Models methods of the OpenAI API integration
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
              display_name: capabilities.format_display_name(model['id']),
              provider: slug,
              type: capabilities.model_type(model['id']),
              family: capabilities.model_family(model['id']),
              metadata: {
                object: model['object'],
                owned_by: model['owned_by']
              },
              context_window: capabilities.context_window_for(model['id']),
              max_tokens: capabilities.max_tokens_for(model['id']),
              supports_vision: capabilities.supports_vision?(model['id']),
              supports_functions: capabilities.supports_functions?(model['id']),
              supports_structured_output: capabilities.supports_structured_output?(model['id']),
              input_price_per_million: capabilities.input_price_for(model['id']),
              output_price_per_million: capabilities.output_price_for(model['id'])
            )
          end
        end
      end
    end
  end
end
