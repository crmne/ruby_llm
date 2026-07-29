# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # Provider-level capability checks and registry fallbacks for MiniMax models.
      module Capabilities
        module_function

        CONTEXT_WINDOWS = {
          'MiniMax-M3' => 1_000_000,
          'MiniMax-M2.7' => 204_800
        }.freeze

        PRICES = {
          'MiniMax-M3' => { input: 0.6, output: 2.4, cache_read: 0.12 },
          'MiniMax-M2.7' => { input: 0.3, output: 1.2, cache_read: 0.06, cache_write: 0.375 }
        }.freeze

        VISION_MODELS = %w[MiniMax-M3].freeze

        def context_window_for(model_id)
          CONTEXT_WINDOWS[model_id]
        end

        def max_tokens_for(_model_id)
          nil
        end

        def critical_capabilities_for(model_id)
          capabilities = %w[function_calling tool_choice reasoning]
          capabilities << 'vision' if VISION_MODELS.include?(model_id)
          capabilities
        end

        def pricing_for(model_id)
          prices = PRICES.fetch(model_id, {})
          standard = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }
          standard[:cache_read_input_per_million] = prices[:cache_read] if prices.key?(:cache_read)
          standard[:cache_write_input_per_million] = prices[:cache_write] if prices.key?(:cache_write)

          { text_tokens: { standard: standard } }
        end
      end
    end
  end
end
