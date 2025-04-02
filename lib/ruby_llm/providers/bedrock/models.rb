# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Models methods for the AWS Bedrock API implementation
      module Models
        def list_models
          @connection = nil # reset connection since base url is different
          @api_base = "https://bedrock.#{RubyLLM.config.bedrock_region}.amazonaws.com"
          full_models_url = "#{@api_base}/#{models_url}"
          signature = sign_request(full_models_url, method: :get)
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
          data.filter { |model| model['modelId'].include?('claude') }
              .map { |model| create_model_info(model, slug, capabilities) }
        end

        def create_model_info(model, slug, capabilities)
          model_id = model['modelId']
          ModelInfo.new(
            **base_model_attributes(model_id, model, slug),
            **capability_attributes(model_id, capabilities),
            **pricing_attributes(model_id, capabilities),
            metadata: build_metadata(model)
          )
        end

        def base_model_attributes(model_id, model, slug)
          {
            id: model_id,
            created_at: nil,
            display_name: model['modelName'] || capabilities.format_display_name(model_id),
            provider: slug
          }
        end

        def capability_attributes(model_id, capabilities)
          {
            context_window: capabilities.context_window_for(model_id),
            max_tokens: capabilities.max_tokens_for(model_id),
            type: capabilities.model_type(model_id),
            family: capabilities.model_family(model_id).to_s,
            supports_vision: capabilities.supports_vision?(model_id),
            supports_functions: capabilities.supports_functions?(model_id),
            supports_json_mode: capabilities.supports_json_mode?(model_id)
          }
        end

        def pricing_attributes(model_id, capabilities)
          {
            input_price_per_million: capabilities.input_price_for(model_id),
            output_price_per_million: capabilities.output_price_for(model_id)
          }
        end

        def build_metadata(model)
          {
            provider_name: model['providerName'],
            customizations_supported: model['customizationsSupported'] || [],
            inference_configurations: model['inferenceTypesSupported'] || [],
            response_streaming_supported: model['responseStreamingSupported'] || false,
            input_modalities: model['inputModalities'] || [],
            output_modalities: model['outputModalities'] || []
          }
        end
      end
    end
  end
end
