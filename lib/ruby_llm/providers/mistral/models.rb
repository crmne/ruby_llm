# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Handles model listing and information for Mistral models
      module Models
        module_function

        def models_url
          "#{Mistral.api_base(RubyLLM.config)}/models"
        end

        def parse_list_models_response(response, slug, capabilities)
          response.body["data"].map do |model|
            parse_model(model, slug, capabilities)
          end
        end

        def parse_model(model, slug, capabilities)
          id = model["id"]

          ModelInfo.new(
            id: id,
            created_at: model["created"] ? Time.at(model["created"]) : nil,
            display_name: capabilities.format_display_name(id),
            provider: slug,
            type: capabilities.model_type(id),
            family: capabilities.model_family(id),
            metadata: {
              object: model["object"],
              owned_by: model["owned_by"],
            },
            context_window: capabilities.context_window_for(id),
            max_tokens: capabilities.max_tokens_for(id),
            supports_vision: capabilities.supports_vision?(id),
            supports_functions: capabilities.supports_functions?(id),
            supports_json_mode: capabilities.supports_json_mode?(id),
            input_price_per_million: capabilities.input_price_for(id),
            output_price_per_million: capabilities.output_price_for(id),
          )
        end
      end
    end
  end
end
