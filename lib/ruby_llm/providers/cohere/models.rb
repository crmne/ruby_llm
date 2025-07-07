# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Model definitions for Cohere API
      # https://docs.cohere.com/reference/list-models
      module Models
        module_function

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug, capabilities)
          data = response.body
          return [] if data.empty?


          data['models']&.map do |model_data|
            model_id = model_data['name']

            Model::Info.new(
              id: model_id,
              name: capabilities.format_display_name(model_id),
              provider: slug,
              family: capabilities.model_family(model_id),
              modalities: capabilities.modalities_for(model_id),
              capabilities: capabilities.capabilities_for(model_id),
              pricing: capabilities.pricing_for(model_id)
            )
          end || []
        end
      end
    end
  end
end
