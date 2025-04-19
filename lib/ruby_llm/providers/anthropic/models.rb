# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Models methods of the Anthropic API integration
      module Models
        private

        def models_url
          '/v1/models'
        end

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          (response.body['data'] || []).map do |model|
            ModelInfo.new(
              id: model['id'],
              created_at: Time.parse(model['created_at']),
              display_name: model['display_name'],
              provider: slug,
              type: capabilities.model_type(model['id']),
              family: capabilities.model_family(model['id']),
              context_window: capabilities.determine_context_window(model['id']),
              max_tokens: capabilities.determine_max_tokens(model['id']),
              supports_vision: capabilities.supports_vision?(model['id']),
              supports_functions: capabilities.supports_functions?(model['id']),
              supports_json_mode: capabilities.supports_json_mode?(model['id']),
              supports_structured_output: capabilities.supports_structured_output?(model['id']),
              input_price_per_million: capabilities.get_input_price(model['id']),
              output_price_per_million: capabilities.get_output_price(model['id'])
            )
          end
        end

        def extract_model_id(data)
          data.dig('message', 'model')
        end

        def extract_input_tokens(data)
          data.dig('message', 'usage', 'input_tokens')
        end

        def extract_output_tokens(data)
          data.dig('message', 'usage', 'output_tokens') || data.dig('usage', 'output_tokens')
        end
      end
    end
  end
end
