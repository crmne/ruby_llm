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

        def list_models(connection:)
          config = connection.config
          response = connection.get('api/tags') do |req|
            req.headers.merge!(headers(config))
          end

          parse_list_models_response(response, slug, capabilities)
        end

        private

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
          (response.body['models'] || []).map do |model|
            model_id = model['name']

            ModelInfo.new(
              id: model_id,
              # NOTE: this is date pulled into the Ollama server, not date of introduction of a model
              created_at: model['modified_at'],
              display_name: model_id,
              provider: slug,
              type: capabilities.model_type(model_id),
              family: model['family'],
              context_window: capabilities.context_window_for(model_id),
              max_tokens: capabilities.max_tokens_for(model_id),
              supports_vision: capabilities.supports_vision?(model_id),
              supports_functions: capabilities.supports_functions?(model_id),
              supports_json_mode: capabilities.supports_json_mode?(model_id),
              input_price_per_million: 0.0,
              output_price_per_million: 0.0,
              metadata: {
                byte_size: model['size']&.to_i,
                parameter_size: model.dig('details', 'parameter_size'),
                quantization_level: model.dig('details', 'quantization_level'),
                format: model.dig('details', 'format'),
                parent_model: model.dig('details', 'parent_model')
              }
            )
          end
        end
      end
    end
  end
end
