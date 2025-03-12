# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Models methods for the Ollama API integration
      module Models
        # Methods needed by Provider - must be public
        def models_url
          'api/tags'
        end

        def list_models
          return [] unless enabled?

          response = connection.get("api/tags") do |req|
            req.headers.merge! headers
          end

          parse_list_models_response(response, slug, capabilities)
        end

        private

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          (response.body['models'] || []).map do |model|
            model_id = model['name']

            ModelInfo.new(
              id: model_id,
              # NOTE: this is date pulled into ollama, not quite date of introduction of a model
              created_at: model['modified_at'],
              display_name: model_id,
              provider: slug,
              type: capabilities.model_type(model_id),
              family: model['family'],
              metadata: {
              },
              context_window: capabilities.context_window_for(model_id),
              max_tokens: capabilities.max_tokens_for(model_id),
              supports_vision: capabilities.supports_vision?(model_id),
              supports_functions: capabilities.supports_functions?(model_id),
              supports_json_mode: capabilities.supports_json_mode?(model_id),
              input_price_per_million: capabilities.input_price_for(model_id),
              output_price_per_million: capabilities.output_price_for(model_id)
            )
          end
        end
      end
    end
  end
end
