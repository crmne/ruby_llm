# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Models methods for the AWS Bedrock API implementation
      module Models
        def list_models(connection:)
          config = connection.config
          mgmt_api_base = "https://bedrock.#{config.bedrock_region}.amazonaws.com"
          full_models_url = "#{mgmt_api_base}/#{models_url}"
          signature = sign_request(full_models_url, config: config, method: :get)
          response = connection.get(full_models_url) do |req|
            req.headers.merge! signature.headers
          end

          parse_list_models_response(response, slug, capabilities)
        end

        module_function

        def models_url
          'foundation-models'
        end

        def parse_list_models_response(response, slug, capabilities)
          models = Array(response.body['modelSummaries'])

          # Filter to include only models we care about
          models.select { |m| m['modelId'].include?('claude') }.map do |model_data|
            model_id = model_data['modelId']

            ModelInfo.new(
              id: model_id_with_region(model_id, model_data),
              name: model_data['modelName'] || capabilities.format_display_name(model_id),
              provider: slug,
              family: capabilities.model_family(model_id),
              created_at: nil,
              context_window: capabilities.context_window_for(model_id),
              max_output_tokens: capabilities.max_tokens_for(model_id),
              modalities: capabilities.modalities_for(model_id),
              capabilities: capabilities.capabilities_for(model_id),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                provider_name: model_data['providerName'],
                inference_types: model_data['inferenceTypesSupported'] || [],
                streaming_supported: model_data['responseStreamingSupported'] || false,
                input_modalities: model_data['inputModalities'] || [],
                output_modalities: model_data['outputModalities'] || []
              }
            )
          end
        end

        # Simple test-friendly method that only sets the ID
        def create_model_info(model_data, slug, _capabilities)
          model_id = model_data['modelId']

          ModelInfo.new(
            id: model_id_with_region(model_id, model_data),
            name: model_data['modelName'] || model_id,
            provider: slug,
            family: 'claude',
            created_at: nil,
            context_window: 200_000,
            max_output_tokens: 4096,
            modalities: { input: ['text'], output: ['text'] },
            capabilities: [],
            pricing: {},
            metadata: {}
          )
        end

        def model_id_with_region(model_id, model_data)
          return model_id unless model_data['inferenceTypesSupported']&.include?('INFERENCE_PROFILE')
          return model_id if model_data['inferenceTypesSupported']&.include?('ON_DEMAND')

          "us.#{model_id}"
        end
      end
    end
  end
end
