module RubyLLM
  module Providers
    module Mistral
      # Handles model listing and information for Mistral models
      module Models
        module_function

        def models_url
          "#{api_base}/models"
        end

        def parse_list_models_response(response, slug, capabilities)
          response.body['data'].map do |model|
            parse_model(model, slug, capabilities)
          end
        end

        def parse_model(model, slug, capabilities)
          id = model['id']

          Model.new(
            id: id,
            name: capabilities.format_display_name(id),
            provider: slug,
            capabilities: capabilities,
            type: capabilities.model_type(id)
          )
        end
      end
    end
  end
end
