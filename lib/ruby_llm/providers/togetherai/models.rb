# frozen_string_literal: true

module RubyLLM
  module Providers
    class TogetherAI
      # Models methods for the Together.ai provider
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, capabilities)
          return [] unless response&.body

          # TogetherAI returns models as an array directly
          models_array = response.body.is_a?(Array) ? response.body : []

          models_array.filter_map do |model_data|
            build_model_info(model_data, slug, capabilities)
          end
        end

        def build_model_info(model_data, slug, capabilities)
          model_id = model_data['id']
          return unless model_id

          created_at = parse_created_at(model_data['created'])

          Model::Info.new(
            id: model_id,
            name: model_data['display_name'] || capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id),
            created_at: created_at,
            context_window: model_data['context_length'] || capabilities.context_window_for(model_id),
            max_output_tokens: capabilities.max_tokens_for(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: capabilities.pricing_for(model_id),
            metadata: build_metadata(model_data)
          )
        end

        def parse_created_at(created_timestamp)
          return unless created_timestamp&.positive?

          Time.at(created_timestamp)
        end

        def build_metadata(model_data)
          {
            object: model_data['object'],
            owned_by: model_data['owned_by'],
            type: model_data['type'],
            organization: model_data['organization'],
            license: model_data['license'],
            link: model_data['link']
          }
        end
      end
    end
  end
end
