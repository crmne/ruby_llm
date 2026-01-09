# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Models methods for the AWS Bedrock API implementation
      module Models
        def list_models
          mgmt_api_base = "https://bedrock.#{@config.bedrock_region}.amazonaws.com"
          full_models_url = "#{mgmt_api_base}/#{models_url}"
          signature = sign_request(full_models_url, method: :get)
          response = @connection.get(full_models_url) do |req|
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

          models.select { |m| m['modelId'].include?('claude') }.map do |model_data|
            model_id = model_data['modelId']

            Model::Info.new(
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

        def create_model_info(model_data, slug, _capabilities)
          model_id = model_data['modelId']

          Model::Info.new(
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
          normalize_inference_profile_id(
            model_id,
            model_data['inferenceTypesSupported'],
            @config.bedrock_region
          )
        end

        def region_prefix(region)
          region = region.to_s
          return 'us' if region.empty?

          region[0, 2]
        end

        def with_region_prefix(model_id, region)
          desired_prefix = region_prefix(region)
          return model_id if model_id.start_with?("#{desired_prefix}.")

          clean_model_id = model_id.sub(/^[a-z]{2}\./, '')
          "#{desired_prefix}.#{clean_model_id}"
        end

        def normalize_inference_profile_id(model_id, inference_types, region)
          types = Array(inference_types)
          return model_id unless types.include?('INFERENCE_PROFILE')
          return model_id if types.include?('ON_DEMAND')

          with_region_prefix(model_id, region)
        end
      end
    end
  end
end
