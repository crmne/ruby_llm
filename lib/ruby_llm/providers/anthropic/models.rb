# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Models methods of the Anthropic API integration
      module Models
        module_function

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model::Info.new(
              id: model_id,
              name: model_data['display_name'] || model_id,
              provider: slug,
              created_at: Time.parse(model_data['created_at']),
              metadata: {}
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

        def extract_cached_tokens(data)
          data.dig('message', 'usage', 'cache_read_input_tokens') || data.dig('usage', 'cache_read_input_tokens')
        end

        def extract_cache_creation_tokens(data)
          direct = data.dig('message', 'usage',
                            'cache_creation_input_tokens') || data.dig('usage', 'cache_creation_input_tokens')
          return direct if direct

          breakdown = data.dig('message', 'usage', 'cache_creation') || data.dig('usage', 'cache_creation')
          return unless breakdown.is_a?(Hash)

          breakdown.values.compact.sum
        end
      end
    end
  end
end
