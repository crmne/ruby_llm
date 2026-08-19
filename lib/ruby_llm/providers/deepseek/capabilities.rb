# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        extend CapabilityTable

        module_function

        CAPABILITIES = {
          'function_calling' => true,
          'tool_choice' => true,
          'structured_output' => /\Adeepseek-v4-/,
          'reasoning' => /\Adeepseek-(?:v4-|reasoner\z)/
        }.freeze

        DEFAULT_CONTEXT_WINDOW = 1_000_000
        DEFAULT_MAX_OUTPUT_TOKENS = 384_000
        DEFAULT_PRICES = {
          input: 0.14,
          output: 0.28,
          cache_read: 0.0028
        }.freeze
        PRO_PRICES = {
          input: 0.435,
          output: 0.87,
          cache_read: 0.003625
        }.freeze

        def context_window_for(_model_id)
          DEFAULT_CONTEXT_WINDOW
        end

        def max_tokens_for(_model_id)
          DEFAULT_MAX_OUTPUT_TOKENS
        end

        def critical_capabilities_for(model_id) = supported_capabilities(model_id)

        def pricing_for(model_id)
          prices = model_id == 'deepseek-v4-pro' ? PRO_PRICES : DEFAULT_PRICES

          {
            text_tokens: {
              standard: {
                input_per_million: prices[:input],
                output_per_million: prices[:output],
                cache_read_input_per_million: prices[:cache_read]
              }
            }
          }
        end
      end
    end
  end
end
