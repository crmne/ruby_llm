# frozen_string_literal: true

require 'time'

module RubyLLM
  module Protocols
    class Cohere
      # Model information for the Cohere API
      module Models
        module_function

        # The model catalog is the one endpoint Cohere still serves from v1.
        def models_url
          'v1/models?page_size=1000'
        end

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['models']).reject { |model| model['is_deprecated'] }.map do |model_data|
            model_id = model_data['name']
            endpoints = Array(model_data['endpoints'])
            release_date = capabilities.release_date_for(model_id)

            Model.new(
              id: model_id,
              name: capabilities.format_display_name(model_id),
              provider: slug,
              family: capabilities.model_family(model_id),
              created_at: release_date && Time.parse(release_date),
              context_window: model_data['context_length']&.to_i || capabilities.context_window_for(model_id),
              max_output_tokens: capabilities.max_tokens_for(model_id),
              modalities: capabilities.modalities_for(model_id),
              capabilities: capabilities.capabilities_for(model_id, endpoints),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                endpoints: endpoints,
                default_endpoints: Array(model_data['default_endpoints']),
                features: Array(model_data['features']),
                finetuned: model_data['finetuned'],
                tokenizer_url: model_data['tokenizer_url']
              }.compact
            )
          end
        end
      end
    end
  end
end
