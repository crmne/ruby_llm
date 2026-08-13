# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Models methods for AWS Bedrock.
      module Models
        module_function

        REGION_PREFIXES = %w[global us eu ap sa ca me af il au jp].freeze

        MANTLE_ENDPOINT = 'mantle'

        def models_api_base
          @config.bedrock_api_base || "https://bedrock.#{bedrock_region}.amazonaws.com"
        end

        def models_url
          '/foundation-models'
        end

        def mantle_models_url
          'v1/models'
        end

        # The mantle catalog reports ids and nothing else, so entries carry
        # only what the endpoint states. models.dev fills in limits and
        # pricing for the ids it knows during a registry refresh.
        def parse_mantle_models_response(response, slug)
          Array(response.body['data']).map do |model_data|
            Model.new(
              id: model_data['id'],
              name: model_data['id'],
              provider: slug,
              created_at: mantle_created_at(model_data['created']),
              modalities: { input: ['text'], output: ['text'] },
              capabilities: ['streaming'],
              metadata: { endpoint: MANTLE_ENDPOINT }
            )
          end
        end

        # Models both catalogs list keep their Converse metadata and gain the
        # mantle tag, because mantle is where RubyLLM sends them.
        def merge_mantle_models(converse_models, mantle_models)
          by_id = converse_models.to_h { |model| [model.id, model] }

          tagged = mantle_models.map do |model|
            listed = by_id.delete(model.id)
            listed ? tag_mantle_endpoint(listed) : model
          end

          by_id.values + tagged
        end

        def tag_mantle_endpoint(model)
          data = model.to_h
          Model.new(data.merge(metadata: data[:metadata].merge(endpoint: MANTLE_ENDPOINT)))
        end

        def mantle_created_at(created)
          Time.at(created).utc if created.is_a?(Numeric)
        end

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['modelSummaries']).map do |model_data|
            create_model_info(model_data, slug)
          end
        end

        def create_model_info(model_data, slug, _capabilities = nil)
          model_id = model_id_with_region(model_data['modelId'], model_data)
          converse_data = model_data['converse'] || {}

          Model.new(
            id: model_id,
            name: model_data['modelName'],
            provider: slug,
            family: model_data['modelFamily'] || model_data['providerName']&.downcase,
            created_at: nil,
            context_window: parse_context_window(model_data),
            max_output_tokens: converse_data['maxTokensDefault'] || converse_data['maxTokensMaximum'],
            modalities: {
              input: normalize_modalities(model_data['inputModalities']),
              output: normalize_modalities(model_data['outputModalities'])
            },
            capabilities: parse_capabilities(model_data),
            pricing: {},
            metadata: {
              provider_name: model_data['providerName'],
              model_arn: model_data['modelArn'],
              inference_types: model_data['inferenceTypesSupported'],
              converse: converse_data
            }
          )
        end

        def model_id_with_region(model_id, model_data)
          inference_types = Array(model_data['inferenceTypesSupported'])
          normalize_inference_profile_id(model_id, inference_types, @config.bedrock_region)
        end

        # Which endpoint serves a model is a fact about the catalogs, not
        # about the id: mantle spells some Converse models differently and
        # lists models Converse has never heard of. The registry records it,
        # so ask the registry first and read the id only for models it does
        # not list.
        #
        # Claude is the exception. Converse only ever serves it under a dated
        # and versioned id, so a bare anthropic. id means mantle even on
        # accounts whose catalog listing hides Claude behind the AWS Sales
        # agreement.
        def mantle_model?(model_id, models)
          return mantle_model_id?(model_id) if model_id.start_with?('anthropic.')

          listed = registered_model(model_id, models)
          return listed.metadata[:endpoint].to_s == MANTLE_ENDPOINT if listed

          mantle_model_id?(model_id)
        end

        def registered_model(model_id, models)
          models.all.find { |model| model.provider == 'bedrock' && model.id == model_id }
        end

        # The bedrock-mantle endpoint serves bare vendor.model ids under
        # exactly that id. Converse ids carry a date or :N version suffix, a
        # cross-region inference prefix, or both.
        def mantle_model_id?(model_id)
          return false if model_id.include?(':') || model_id.match?(/\d{8}/)
          return false if region_prefixed?(model_id)

          model_id.include?('.')
        end

        def resolve_registry_id(model_id, models, config)
          region = config.bedrock_region.to_s
          return model_id if region.empty?
          return model_id if mantle_model_id?(model_id)

          candidate_id = with_region_prefix(model_id, region)
          return model_id if candidate_id == model_id

          candidate = models.all.find { |m| m.provider == 'bedrock' && m.id == candidate_id }
          return model_id unless candidate

          inference_types = Array(candidate.metadata[:inference_types] || candidate.metadata['inference_types'])
          normalize_inference_profile_id(model_id, inference_types, region)
        end

        def normalize_inference_profile_id(model_id, inference_types, region)
          return model_id unless inference_types.include?('INFERENCE_PROFILE')
          return model_id if inference_types.include?('ON_DEMAND')

          with_region_prefix(model_id, region)
        end

        def with_region_prefix(model_id, region)
          prefix = region_prefix(region)

          if region_prefixed?(model_id)
            model_id.sub(/\A(?:#{REGION_PREFIXES.join('|')})\./, "#{prefix}.")
          else
            "#{prefix}.#{model_id}"
          end
        end

        def region_prefix(region)
          prefix = region.to_s.split('-').first
          prefix = '' if prefix.nil?
          prefix.empty? ? 'us' : prefix
        end

        def region_prefixed?(model_id)
          model_id.match?(/\A(?:#{REGION_PREFIXES.join('|')})\./)
        end

        def normalize_modalities(modalities)
          Array(modalities).map do |modality|
            normalized = modality.to_s.downcase
            case normalized
            when 'embedding' then 'embeddings'
            when 'speech' then 'audio'
            else normalized
            end
          end
        end

        def parse_capabilities(model_data)
          capabilities = []
          capabilities << 'streaming' if model_data['responseStreamingSupported']

          converse = model_data['converse'] || {}
          capabilities << 'function_calling' if converse.is_a?(Hash)
          capabilities << 'reasoning' if converse.dig('reasoningSupported', 'embedded')
          capabilities << 'structured_output' if supports_structured_output?(model_data['modelId'])

          capabilities
        end

        # Structured output supported on Claude 4.5+ and assumed for future major versions.
        # Bedrock IDs look like: us.anthropic.claude-haiku-4-5-20251001-v1:0
        # Must handle optional region prefix (us./eu./global.) and anthropic. prefix.
        def supports_structured_output?(model_id)
          return false unless model_id

          normalized = model_id.sub(/\A(?:#{REGION_PREFIXES.join('|')})\./, '').delete_prefix('anthropic.')
          match = normalized.match(/claude-(?:opus|sonnet|haiku)-(\d+)-(\d{1,2})(?:\b|-)/)
          return false unless match

          major = match[1].to_i
          minor = match[2].to_i
          major > 4 || (major == 4 && minor >= 5)
        end

        def parse_context_window(model_data)
          value = model_data.dig('description', 'maxContextWindow')
          return unless value.is_a?(String)

          if value.match?(/\A\d+[kK]\z/)
            value.to_i * 1000
          elsif value.match?(/\A\d+\z/)
            value.to_i
          end
        end
      end
    end
  end
end
