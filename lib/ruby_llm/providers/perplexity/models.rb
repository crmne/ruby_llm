# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Models methods of the Perplexity API integration
      module Models
        SEARCH_MODEL_IDS = %w[
          sonar
          sonar-pro
          sonar-reasoning-pro
          sonar-deep-research
        ].freeze
        EMBEDDING_MODEL_IDS = %w[
          pplx-embed-v1-0.6b
          pplx-embed-v1-4b
        ].freeze
        STATIC_MODEL_IDS = (SEARCH_MODEL_IDS + EMBEDDING_MODEL_IDS).freeze

        def models_url
          'v1/models'
        end

        def list_models
          super
        rescue Error => e
          RubyLLM.logger.warn "Perplexity models endpoint failed (#{e.message}). Using the static model list."
          static_models(@provider.slug, @provider.capabilities)
        end

        # The models endpoint lists the multi-model catalog but not the search
        # or embedding models, so those ride along statically.
        def parse_list_models_response(response, slug, capabilities)
          listed = Array(response.body['data']).map do |model_data|
            create_model_info(model_data['id'], slug, capabilities, pricing: endpoint_pricing(model_data['pricing']))
          end

          static_models(slug, capabilities, ids: STATIC_MODEL_IDS - listed.map(&:id)) + listed
        end

        def static_models(slug, capabilities, ids: STATIC_MODEL_IDS)
          ids.map { |id| create_model_info(id, slug, capabilities) }
        end

        def create_model_info(id, slug, capabilities, pricing: nil)
          Model.new(
            id: id,
            name: id,
            provider: slug,
            context_window: capabilities.context_window_for(id),
            max_output_tokens: capabilities.max_tokens_for(id),
            capabilities: capabilities.critical_capabilities_for(id),
            pricing: pricing || capabilities.pricing_for(id),
            modalities: modalities_for(id),
            metadata: {}
          )
        end

        def modalities_for(id)
          { input: %w[text], output: %w[embeddings] } if EMBEDDING_MODEL_IDS.include?(id)
        end

        def endpoint_pricing(pricing)
          return nil unless pricing.is_a?(Hash)

          standard = {
            input_per_million: pricing['input'],
            output_per_million: pricing['output'],
            cache_read_input_per_million: pricing['cache_read'],
            cache_write_input_per_million: pricing['cache_write']
          }.compact
          { text_tokens: { standard: standard } } unless standard.empty?
        end
      end
    end
  end
end
