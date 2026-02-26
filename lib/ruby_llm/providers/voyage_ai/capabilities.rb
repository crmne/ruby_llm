# frozen_string_literal: true

module RubyLLM
  module Providers
    class VoyageAI
      # Determines capabilities for Voyage AI models
      module Capabilities
        module_function

        MODEL_CATALOG = {
          'voyage-4-large' => {
            name: 'Voyage 4 Large',
            family: 'voyage-4',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2026-01-15',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-4' => {
            name: 'Voyage 4',
            family: 'voyage-4',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.06 } } },
            release_date: '2026-01-15',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-4-lite' => {
            name: 'Voyage 4 Lite',
            family: 'voyage-4',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.02 } } },
            release_date: '2026-01-15',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-4-nano' => {
            name: 'Voyage 4 Nano',
            family: 'voyage-4',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: {},
            release_date: '2026-01-15',
            metadata: {
              dimensions: 512,
              supports_custom_dimensions: true,
              available_dimensions: [128, 256, 512]
            }
          },
          'voyage-code-3' => {
            name: 'Voyage Code 3',
            family: 'voyage-code',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.18 } } },
            release_date: '2024-12-04',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-finance-2' => {
            name: 'Voyage Finance 2',
            family: 'voyage-finance',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2024-06-03',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: false,
              available_dimensions: [1024]
            }
          },
          'voyage-law-2' => {
            name: 'Voyage Law 2',
            family: 'voyage-law',
            context_window: 16_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2024-04-15',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: false,
              available_dimensions: [1024]
            }
          },
          'voyage-multilingual-2' => {
            name: 'Voyage Multilingual 2',
            family: 'voyage-multilingual',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2024-01-01',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-3-large' => {
            name: 'Voyage 3 Large',
            family: 'voyage-3',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.18 } } },
            release_date: '2025-01-07',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-3.5' => {
            name: 'Voyage 3.5',
            family: 'voyage-3',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.06 } } },
            release_date: '2025-05-20',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-3.5-lite' => {
            name: 'Voyage 3.5 Lite',
            family: 'voyage-3',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.02 } } },
            release_date: '2025-05-20',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-code-2' => {
            name: 'Voyage Code 2',
            family: 'voyage-code',
            context_window: 16_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2024-01-23',
            metadata: {
              dimensions: 1536,
              supports_custom_dimensions: false,
              available_dimensions: [1536]
            }
          },
          'voyage-context-3' => {
            name: 'Voyage Context 3',
            family: 'voyage-context',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.18 } } },
            release_date: nil,
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048]
            }
          },
          'voyage-multimodal-3.5' => {
            name: 'Voyage Multimodal 3.5',
            family: 'voyage-multimodal',
            context_window: 32_000,
            modalities: { input: %w[text image video], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2026-01-15',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: true,
              available_dimensions: [256, 512, 1024, 2048],
              price_per_billion_pixels: 0.60
            }
          },
          'voyage-multimodal-3' => {
            name: 'Voyage Multimodal 3',
            family: 'voyage-multimodal',
            context_window: 32_000,
            modalities: { input: %w[text image], output: ['embeddings'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.12 } } },
            release_date: '2024-11-12',
            metadata: {
              dimensions: 1024,
              supports_custom_dimensions: false,
              available_dimensions: [1024],
              price_per_billion_pixels: 0.60
            }
          },
          'rerank-2.5' => {
            name: 'Rerank 2.5',
            family: 'voyage-rerank',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['rerank'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.05 } } },
            release_date: '2025-08-11',
            metadata: {}
          },
          'rerank-2.5-lite' => {
            name: 'Rerank 2.5 Lite',
            family: 'voyage-rerank',
            context_window: 32_000,
            modalities: { input: ['text'], output: ['rerank'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.02 } } },
            release_date: '2025-08-11',
            metadata: {}
          },
          'rerank-2' => {
            name: 'Rerank 2',
            family: 'voyage-rerank',
            context_window: 16_000,
            modalities: { input: ['text'], output: ['rerank'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.05 } } },
            release_date: '2024-09-30',
            metadata: {}
          },
          'rerank-2-lite' => {
            name: 'Rerank 2 Lite',
            family: 'voyage-rerank',
            context_window: 8_000,
            modalities: { input: ['text'], output: ['rerank'] },
            capabilities: [],
            pricing: { text_tokens: { standard: { input_per_million: 0.02 } } },
            release_date: '2024-09-30',
            metadata: {}
          }
        }.freeze

        def model_ids
          MODEL_CATALOG.keys
        end

        def supports_streaming?(_model_id)
          false
        end

        def supports_tools?(_model_id)
          false
        end

        def supports_vision?(model_id)
          modalities_for(model_id)[:input].include?('image')
        end

        def supports_json_mode?(_model_id)
          false
        end

        def format_display_name(model_id)
          model_data_for(model_id)[:name] || model_id.split('-').map(&:capitalize).join(' ')
        end

        def model_family(model_id)
          model_data_for(model_id)[:family] || 'voyage'
        end

        def context_window_for(model_id)
          model_data_for(model_id)[:context_window]
        end

        def max_tokens_for(_model_id)
          nil
        end

        def modalities_for(model_id)
          deep_dup(model_data_for(model_id)[:modalities] || { input: ['text'], output: ['embeddings'] })
        end

        def capabilities_for(model_id)
          deep_dup(model_data_for(model_id)[:capabilities] || [])
        end

        def pricing_for(model_id)
          deep_dup(model_data_for(model_id)[:pricing] || {})
        end

        def release_date_for(model_id)
          model_data_for(model_id)[:release_date]
        end

        def metadata_for(model_id)
          deep_dup(model_data_for(model_id)[:metadata] || {})
        end

        def model_data_for(model_id)
          MODEL_CATALOG.fetch(model_id) do
            {
              family: 'voyage',
              context_window: 32_000,
              modalities: { input: ['text'], output: ['embeddings'] },
              capabilities: [],
              pricing: {},
              metadata: {}
            }
          end
        end

        def deep_dup(value)
          case value
          when Hash
            value.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
          when Array
            value.map { |v| deep_dup(v) }
          else
            value
          end
        end
      end
    end
  end
end
