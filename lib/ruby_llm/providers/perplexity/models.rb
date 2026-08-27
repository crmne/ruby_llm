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
        STATIC_MODEL_DATA = {
          'sonar' => {
            context_window: 128_000, input_price: 1.0, output_price: 1.0,
            capabilities: %w[streaming structured_output citations]
          },
          'sonar-pro' => {
            context_window: 200_000, input_price: 3.0, output_price: 15.0,
            capabilities: %w[streaming structured_output citations]
          },
          'sonar-reasoning-pro' => {
            context_window: 128_000, input_price: 2.0, output_price: 8.0,
            capabilities: %w[streaming structured_output citations reasoning]
          },
          'sonar-deep-research' => {
            context_window: 128_000, input_price: 2.0, output_price: 8.0, reasoning_price: 3.0,
            capabilities: %w[streaming structured_output citations reasoning]
          },
          'pplx-embed-v1-0.6b' => { context_window: 32_768, input_price: 0.004 },
          'pplx-embed-v1-4b' => { context_window: 32_768, input_price: 0.03 }
        }.freeze

        def models_url
          'v1/models'
        end

        def list_models
          super
        rescue Error => e
          RubyLLM.logger.warn "Perplexity models endpoint failed (#{e.message}). Using the static model list."
          static_models(@provider.slug)
        end

        # The models endpoint lists the multi-model catalog but not the search
        # or embedding models, so those ride along statically.
        def parse_list_models_response(response, slug)
          listed = Array(response.body['data']).map do |model_data|
            create_model_info(model_data['id'], slug, pricing: endpoint_pricing(model_data['pricing']))
          end

          static_models(slug, ids: STATIC_MODEL_IDS - listed.map(&:id)) + listed
        end

        def static_models(slug, ids: STATIC_MODEL_IDS)
          ids.map { |id| create_model_info(id, slug) }
        end

        def create_model_info(id, slug, pricing: nil)
          static = STATIC_MODEL_DATA.fetch(id, {})

          Model.new(
            id: id,
            name: id,
            provider: slug,
            context_window: static[:context_window],
            capabilities: static.fetch(:capabilities, []),
            pricing: pricing || static_pricing(static),
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

        def static_pricing(data)
          return {} unless data[:input_price]

          standard = { input_per_million: data[:input_price] }
          standard[:output_per_million] = data[:output_price] if data[:output_price]
          standard[:reasoning_output_per_million] = data[:reasoning_price] if data[:reasoning_price]
          { text_tokens: { standard: standard } }
        end
      end
    end
  end
end
