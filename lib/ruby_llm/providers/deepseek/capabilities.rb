# frozen_string_literal: true

module RubyLLM
  module Providers
    class DeepSeek
      # Provider-level capability checks used outside the model registry.
      module Capabilities
        module_function

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

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          false
        end

        def context_window_for(_model_id)
          DEFAULT_CONTEXT_WINDOW
        end

        def max_tokens_for(_model_id)
          DEFAULT_MAX_OUTPUT_TOKENS
        end

        def critical_capabilities_for(model_id)
          v4_model = model_id.start_with?('deepseek-v4-')
          capabilities = ['function_calling']
          capabilities << 'structured_output' if v4_model
          capabilities << 'reasoning' if model_id == 'deepseek-reasoner' || v4_model
          capabilities
        end

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
