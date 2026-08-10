# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Models methods of the GPUStack API integration. GPUStack 2.x serves
      # the plain OpenAI list format at /v1/models; categories arrive through
      # per-category queries because the list response doesn't include them.
      module Models
        CATEGORIES = %w[llm embedding image reranker speech_to_text text_to_speech unknown].freeze

        def models_url
          'models?with_meta=true'
        end

        def list_models
          models = {}
          CATEGORIES.each do |category|
            data = @connection.get("#{models_url}&categories=#{category}").body['data'] || []
            data.each do |model|
              entry = models[model['id']] ||= model.merge('categories' => [])
              entry['categories'] << category
            end
          end
          models.values.map { |model| build_model(model, @provider.slug) }
        end

        def parse_list_models_response(response, slug, _capabilities)
          data = response.body['data'] || []
          data.map { |model| build_model(model, slug) }
        end

        private

        def build_model(model, slug)
          meta = model['meta'] || {}
          categories = model['categories'] || []

          Model.new(
            id: model['id'],
            name: model['id'],
            created_at: model['created'] ? Time.at(model['created']) : nil,
            provider: slug,
            family: 'gpustack',
            context_window: context_window(meta),
            max_output_tokens: context_window(meta),
            capabilities: build_capabilities(categories, meta),
            modalities: build_modalities(categories, meta),
            pricing: {},
            metadata: {
              owned_by: model['owned_by'],
              categories: categories,
              meta: model['meta']
            }
          )
        end

        def context_window(meta)
          meta['n_ctx'] || meta['max_model_len']
        end

        def build_capabilities(categories, meta)
          return [] unless categories.include?('llm')

          capabilities = %w[streaming structured_output json_mode]
          capabilities << 'function_calling' if meta['support_tool_calls']
          capabilities << 'vision' if meta['support_vision']
          capabilities << 'reasoning' if meta['support_reasoning']
          capabilities
        end

        def build_modalities(categories, meta)
          {
            input: input_modalities(categories, meta),
            output: output_modalities(categories)
          }
        end

        def input_modalities(categories, meta)
          inputs = []
          inputs << 'text' if categories.intersect?(%w[llm embedding image reranker text_to_speech])
          inputs << 'image' if categories.include?('llm') && meta['support_vision']
          inputs << 'audio' if audio_input?(categories, meta)
          inputs
        end

        def audio_input?(categories, meta)
          categories.include?('speech_to_text') || (categories.include?('llm') && meta['support_audio'])
        end

        def output_modalities(categories)
          outputs = []
          outputs << 'text' if categories.intersect?(%w[llm speech_to_text reranker])
          outputs << 'embeddings' if categories.include?('embedding')
          outputs << 'image' if categories.include?('image')
          outputs << 'audio' if categories.include?('text_to_speech')
          outputs
        end
      end
    end
  end
end
