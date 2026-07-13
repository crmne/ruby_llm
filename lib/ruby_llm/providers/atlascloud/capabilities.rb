# frozen_string_literal: true

module RubyLLM
  module Providers
    class AtlasCloud
      # Provider-level capability metadata for Atlas Cloud models.
      module Capabilities
        module_function

        MODEL_LIMITS = {
          'deepseek-ai/deepseek-v4-pro' => {
            context_window: 1_048_576,
            max_output_tokens: 393_216
          },
          'qwen/qwen3.5-flash' => {
            context_window: 1_000_000,
            max_output_tokens: 67_072
          }
        }.freeze

        DEFAULT_CONTEXT_WINDOW = 1_000_000
        DEFAULT_MAX_OUTPUT_TOKENS = 67_072

        def context_window_for(model_id)
          MODEL_LIMITS.dig(model_id, :context_window) || DEFAULT_CONTEXT_WINDOW
        end

        def max_tokens_for(model_id)
          MODEL_LIMITS.dig(model_id, :max_output_tokens) || DEFAULT_MAX_OUTPUT_TOKENS
        end

        def critical_capabilities_for(_model_id)
          []
        end

        def pricing_for(_model_id)
          {}
        end
      end
    end
  end
end
