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

        # FIXME: include aliases for tags with the format \d+m or \d+b
        # ie. given these models in the server,
        # - gemma3:27b
        # - gemma3:9b
        #
        # create an alias gemma3 for gemma3:27b

        # NOTE: Unlike other providers for well known APIs with stable model
        # offerings, the Ollama provider deals with local servers which
        # might have arbitrarily named models or even zero models installed.
        #
        # Thus, this provider can't ship hardcoded assumptions in models.json
        # and thus no Ollama models will be known at runtime, so you'll need a
        # `RubyLLM.models.refresh!` to populate your instance's models.

        def list_models
          return [] unless enabled?

          response = connection.get('api/tags') do |req|
            req.headers.merge! headers
          end

          parse_list_models_response(response, slug, capabilities)
        end

        private

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/MethodLength
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
              metadata: {},
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
