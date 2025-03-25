# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Models methods for the AWS Bedrock API implementation
      module Models

        def list_models
          @connection = nil # reset connection since base url is different
          @api_base = "https://bedrock.#{RubyLLM.config.bedrock_region}.amazonaws.com"
          signature = sign_request(models_url, nil, streaming: block_given?)
          response = connection.get(models_url) do |req|
            req.headers.merge! signature.headers
          end
          @connection = nil # reset connection since base url is different

          parse_list_models_response(response, slug, capabilities)
        end

        module_function

        def models_url
          'foundation-models'
        end

        def parse_list_models_response(response, slug, capabilities)
          data = response.body['modelSummaries'] || []

          data = data.filter { |model| model['modelId'].include?('claude') }
          data.map do |model|
            model_id = model['modelId']
            ModelInfo.new(
              id: model_id,
              created_at: nil,
              display_name: model['modelName'] || capabilities.format_display_name(model_id),
              provider: slug,
              context_window: capabilities.context_window_for(model_id),
              max_tokens: capabilities.max_tokens_for(model_id),
              type: capabilities.model_type(model_id),
              family: capabilities.model_family(model_id).to_s,
              supports_vision: capabilities.supports_vision?(model_id),
              supports_functions: capabilities.supports_functions?(model_id),
              supports_json_mode: capabilities.supports_json_mode?(model_id),
              input_price_per_million: capabilities.input_price_for(model_id),
              output_price_per_million: capabilities.output_price_for(model_id),
              metadata: {
                provider_name: model['providerName'],
                customizations_supported: model['customizationsSupported'] || [],
                inference_configurations: model['inferenceTypesSupported'] || [],
                response_streaming_supported: model['responseStreamingSupported'] || false,
                input_modalities: model['inputModalities'] || [],
                output_modalities: model['outputModalities'] || []
              }
            )
          end
        end
      end
    end
  end
end
