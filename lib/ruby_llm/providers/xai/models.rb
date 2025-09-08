# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Model definitions for xAI API
      # https://docs.x.ai/docs/api-reference#list-language-models
      # https://docs.x.ai/docs/api-reference#list-image-generation-models
      module Models
        module_function

        # NOTE: We pull models list from two endpoints here as these provide
        #       detailed, modality, capability and cost information for each
        #       model that we can leverage which the generic OpenAI compatible
        #       /models endpoint does not provide.
        def models_url
          %w[language-models image-generation-models]
        end

        def parse_list_models_response(response, slug, capabilities)
          data = response.body
          return [] if data.empty?

          data['models']&.map do |model_data|
            model_id = model_data['id']

            Model::Info.new(
              id: model_id,
              name: capabilities.format_display_name(model_id),
              provider: slug,
              family: capabilities.model_family(model_id),
              modalities: {
                input: model_data['input_modalities'] | capabilities.modalities_for(model_id)[:input],
                output: model_data['output_modalities'] | capabilities.modalities_for(model_id)[:output]
              },
              context_window: capabilities.context_window_for(model_id),
              capabilities: capabilities.capabilities_for(model_id),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                aliases: model_data['aliases']
              }
            )
          end || []
        end
      end
    end
  end
end
