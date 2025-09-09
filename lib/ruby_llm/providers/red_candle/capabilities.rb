# frozen_string_literal: true

module RubyLLM
  module Providers
    class RedCandle
      # Determines capabilities and pricing for RedCandle models
      module Capabilities
        module_function

        def supports_vision?
          false
        end

        def supports_functions?(_model_id = nil)
          false
        end

        def supports_streaming?
          true
        end

        def supports_structured_output?
          true
        end

        def supports_regex_constraints?
          true
        end

        def supports_embeddings?
          false # Future enhancement - Red Candle does support embedding models
        end

        def supports_audio?
          false
        end

        def supports_pdf?
          false
        end

        def normalize_temperature(temperature, _model_id)
          # Red Candle uses standard 0-2 range
          return 0.7 if temperature.nil?

          temperature = temperature.to_f
          temperature.clamp(0.0, 2.0)
        end

        def model_context_window(model_id)
          case model_id
          when /gemma-3-4b/i
            8192
          when /qwen2\.5-0\.5b/i
            32_768
          else
            4096 # Conservative default
          end
        end

        def pricing
          # Local execution - no API costs
          {
            input_tokens_per_dollar: Float::INFINITY,
            output_tokens_per_dollar: Float::INFINITY,
            input_price_per_million_tokens: 0.0,
            output_price_per_million_tokens: 0.0
          }
        end

        def default_max_tokens
          512
        end

        def max_temperature
          2.0
        end

        def min_temperature
          0.0
        end

        def supports_temperature?
          true
        end

        def supports_top_p?
          true
        end

        def supports_top_k?
          true
        end

        def supports_repetition_penalty?
          true
        end

        def supports_seed?
          true
        end

        def supports_stop_sequences?
          true
        end

        def model_families
          %w[gemma qwen]
        end

        def available_on_platform?
          # Check if Candle can be loaded

          require 'candle'
          true
        rescue LoadError
          false
        end
      end
    end
  end
end
