# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini
      # Provider-level capability checks and narrow registry fallbacks.
      module Capabilities
        module_function

        PRICES = {
          flash_2: { input: 0.10, output: 0.40 }, # rubocop:disable Naming/VariableNumber
          flash_lite_2: { input: 0.075, output: 0.30 }, # rubocop:disable Naming/VariableNumber
          flash: { input: 0.075, output: 0.30 },
          flash_8b: { input: 0.0375, output: 0.15 },
          pro: { input: 1.25, output: 5.0 },
          pro_2_5: { input: 0.12, output: 0.50 }, # rubocop:disable Naming/VariableNumber
          gemini_embedding: { input: 0.002, output: 0.004 },
          embedding: { input: 0.00, output: 0.00 },
          imagen: { price: 0.03 },
          aqa: { input: 0.00, output: 0.00 }
        }.freeze

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          false
        end

        def context_window_for(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/, /gemini-2\.0-flash/, /gemini-2\.0-flash-lite/, /gemini-1\.5-flash/,
               /gemini-1\.5-flash-8b/
            1_048_576
          when /gemini-1\.5-pro/ then 2_097_152
          when /gemini-embedding-exp/ then 8_192
          when /text-embedding-004/, /embedding-001/ then 2_048
          when /aqa/ then 7_168
          when /imagen-3/ then nil
          else 32_768
          end
        end

        def max_tokens_for(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/ then 64_000
          when /gemini-2\.0-flash/, /gemini-2\.0-flash-lite/, /gemini-1\.5-flash/, /gemini-1\.5-flash-8b/,
               /gemini-1\.5-pro/
            8_192
          when /gemini-embedding-exp/ then nil
          when /text-embedding-004/, /embedding-001/ then 768
          when /imagen-3/ then 4
          else 4_096
          end
        end

        def critical_capabilities_for(model_id)
          capabilities = []
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_structured_output?(model_id)
          capabilities << 'vision' if supports_vision?(model_id)
          capabilities
        end

        def pricing_for(model_id)
          prices = PRICES.fetch(pricing_family(model_id), { input: 0.075, output: 0.30 })
          {
            text_tokens: {
              standard: {
                input_per_million: prices[:input] || prices[:price] || 0.075,
                output_per_million: prices[:output] || prices[:price] || 0.30
              }
            }
          }
        end

        def supports_vision?(model_id)
          return false if model_id.match?(/text-embedding|embedding-001|aqa/)

          model_id.match?(/gemini|flash|pro|imagen/)
        end

        def supports_functions?(model_id)
          return false if model_id.match?(/text-embedding|embedding-001|aqa|flash-lite|imagen|gemini-2\.0-flash-lite/)

          model_id.match?(/gemini|pro|flash/)
        end

        def supports_structured_output?(model_id)
          if model_id.match?(/text-embedding|embedding-001|aqa|imagen|gemini-2\.0-flash-lite|gemini-2\.5-pro-exp-03-25/)
            return false
          end

          model_id.match?(/gemini|pro|flash/)
        end

        def pricing_family(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/ then :pro_2_5 # rubocop:disable Naming/VariableNumber
          when /gemini-2\.0-flash-lite/ then :flash_lite_2 # rubocop:disable Naming/VariableNumber
          when /gemini-2\.0-flash/ then :flash_2 # rubocop:disable Naming/VariableNumber
          when /gemini-1\.5-flash-8b/ then :flash_8b
          when /gemini-1\.5-flash/ then :flash
          when /gemini-1\.5-pro/ then :pro
          when /gemini-embedding-exp/ then :gemini_embedding
          when /text-embedding|embedding/ then :embedding
          when /imagen/ then :imagen
          when /aqa/ then :aqa
          else :base
          end
        end

        module_function :context_window_for, :max_tokens_for, :critical_capabilities_for, :pricing_for,
                        :supports_vision?, :supports_functions?, :supports_structured_output?, :pricing_family
      end
    end
  end
end
