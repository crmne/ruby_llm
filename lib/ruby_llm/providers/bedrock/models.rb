# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Models methods for AWS Bedrock.
      module Models
        module_function

        JP_REGIONS = %w[ap-northeast-1 ap-northeast-3].freeze
        AU_REGIONS = %w[ap-southeast-2 ap-southeast-4].freeze

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

        def models_dev_alias(model_id, models_dev_by_key, _provider_model = nil)
          normalized_id = model_id.sub(/^[a-z]{2}\./, '')
          context_override = nil
          normalized_id = normalized_id.gsub(/:(\d+)k\b/) do
            context_override = Regexp.last_match(1).to_i * 1000
            ''
          end
          source = models_dev_by_key["bedrock:#{normalized_id}"]
          return unless source

          data = source.to_h.merge(id: model_id)
          data[:context_window] = context_override if context_override
          Model.new(data)
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

        def parse_list_models_response(response, slug, profile_ids: [])
          Array(response.body['modelSummaries']).map do |model_data|
            create_model_info(model_data, slug, profile_ids:)
          end
        end

        # The region's actual cross-region inference profile ids. Some
        # geography prefixes cannot be synthesized from the region alone:
        # Tokyo serves both apac. and jp. profiles.
        def inference_profile_ids
          ids = []
          token = nil

          loop do
            url = +'/inference-profiles?maxResults=1000&typeEquals=SYSTEM_DEFINED'
            url << "&nextToken=#{URI.encode_www_form_component(token)}" if token
            body = signed_get(models_api_base, url).body
            ids.concat(Array(body['inferenceProfileSummaries']).map { |summary| summary['inferenceProfileId'] })
            token = body['nextToken']
            break unless token
          end

          ids.compact
        rescue StandardError => e
          RubyLLM.logger.debug { "Error fetching Bedrock inference profiles: #{e.message}" }
          []
        end

        def create_model_info(model_data, slug, _capabilities = nil, profile_ids: [])
          model_id = model_id_with_region(model_data['modelId'], model_data, profile_ids)
          converse_data = model_data['converse'] || {}

          Model.new(
            id: model_id,
            name: model_data['modelName'],
            provider: slug,
            family: model_data['modelFamily'] || model_data['providerName']&.downcase,
            created_at: nil,
            context_window: parse_context_window(model_data),
            max_output_tokens: converse_data['maxTokensMaximum'] || converse_data['maxTokensDefault'],
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

        def model_id_with_region(model_id, model_data, profile_ids = [])
          inference_types = Array(model_data['inferenceTypesSupported'])
          return model_id unless inference_profile_only?(inference_types)

          listed_profile_id(model_id, profile_ids) || with_region_prefix(model_id, @config.bedrock_region)
        end

        def listed_profile_id(model_id, profile_ids)
          candidates = profile_ids.select { |profile_id| profile_id.end_with?(".#{model_id}") }
          preferred = region_prefix_candidates(@config.bedrock_region).filter_map do |prefix|
            candidates.find { |profile_id| profile_id == "#{prefix}.#{model_id}" }
          end.first

          preferred || candidates.first
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
          models.all_including_unlisted.find { |model| model.provider == 'bedrock' && model.id == model_id }
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

          candidate = registered_profile_candidate(model_id, models, region)
          return model_id unless candidate

          inference_types = Array(candidate.metadata[:inference_types] || candidate.metadata['inference_types'])
          inference_profile_only?(inference_types) ? candidate.id : model_id
        end

        def registered_profile_candidate(model_id, models, region)
          region_prefix_candidates(region).each do |prefix|
            prefixed = prefixed_with(model_id, prefix)
            next if prefixed == model_id

            candidate = models.all_including_unlisted.find { |m| m.provider == 'bedrock' && m.id == prefixed }
            return candidate if candidate
          end

          nil
        end

        def inference_profile_only?(inference_types)
          inference_types.include?('INFERENCE_PROFILE') && !inference_types.include?('ON_DEMAND')
        end

        def normalize_inference_profile_id(model_id, inference_types, region)
          return model_id unless inference_profile_only?(inference_types)

          with_region_prefix(model_id, region)
        end

        def with_region_prefix(model_id, region)
          prefixed_with(model_id, region_prefix(region))
        end

        def prefixed_with(model_id, prefix)
          if region_prefixed?(model_id)
            model_id.sub(/\A(?:#{Protocols::Converse::REGION_PREFIXES.join('|')})\./, "#{prefix}.")
          else
            "#{prefix}.#{model_id}"
          end
        end

        # Inference profile ids use geography prefixes, not region name
        # segments: ap-* regions are apac., GovCloud is us-gov.
        def region_prefix(region)
          region = region.to_s
          return 'us' if region.empty?
          return 'us-gov' if region.start_with?('us-gov')

          geography = region.split('-').first
          geography == 'ap' ? 'apac' : geography
        end

        # Countries with their own residency-preserving profiles come before
        # the broad geography, so Tokyo prefers jp. over apac. Some models
        # ship with only a global. profile, so that is the last resort.
        def region_prefix_candidates(region)
          region = region.to_s
          specific = ('jp' if JP_REGIONS.include?(region)) || ('au' if AU_REGIONS.include?(region))
          [specific, region_prefix(region), 'global'].compact
        end

        def region_prefixed?(model_id)
          model_id.match?(/\A(?:#{Protocols::Converse::REGION_PREFIXES.join('|')})\./)
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

        # A summary's converse block is metadata Bedrock fills in for some
        # models, not a statement that Converse serves them: Nova Lite,
        # Llama 3.3 and Mistral Large take tool calls without one. Whether
        # Converse accepts the model at all is the closest thing the listing
        # has to a tool-use flag.
        def parse_capabilities(model_data)
          capabilities = []
          capabilities << 'streaming' if model_data['responseStreamingSupported']

          converse = model_data['converse'] || {}
          capabilities << 'function_calling' if model_data.dig('inferenceAPIsSupported', 'converse', 'sync')
          capabilities << 'reasoning' if converse.dig('reasoningSupported', 'embedded')

          capabilities
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
