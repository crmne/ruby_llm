# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Provider-level capability checks and narrow registry fallbacks.
      module Capabilities
        module_function

        PRICES = {
          sonar: { input: 1.0, output: 1.0 },
          sonar_pro: { input: 3.0, output: 15.0 },
          sonar_reasoning: { input: 1.0, output: 5.0 },
          sonar_reasoning_pro: { input: 2.0, output: 8.0 },
          sonar_deep_research: {
            input: 2.0,
            output: 8.0,
            reasoning_output: 3.0
          }
        }.freeze

        def supports_tool_choice?(_model_id)
          false
        end

        def supports_tool_parallel_control?(_model_id)
          false
        end

        def context_window_for(model_id)
          model_id.match?(/sonar-pro/) ? 200_000 : 128_000
        end

        def max_tokens_for(model_id)
          model_id.match?(/sonar-(?:pro|reasoning-pro)/) ? 8_192 : 4_096
        end

        def critical_capabilities_for(model_id)
          capabilities = []
          capabilities << 'vision' if model_id.match?(/sonar(?:-pro|-reasoning(?:-pro)?)?$/)
          capabilities << 'reasoning' if model_id.match?(/reasoning|deep-research/)
          capabilities
        end

        def pricing_for(model_id)
          prices = PRICES.fetch(model_family(model_id), { input: 1.0, output: 1.0 })

          standard = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }
          standard[:reasoning_output_per_million] = prices[:reasoning_output] if prices[:reasoning_output]

          { text_tokens: { standard: standard } }
        end

        def model_family(model_id)
          case model_id
          when 'sonar' then :sonar
          when 'sonar-pro' then :sonar_pro
          when 'sonar-reasoning' then :sonar_reasoning
          when 'sonar-reasoning-pro' then :sonar_reasoning_pro
          when 'sonar-deep-research' then :sonar_deep_research
          else :unknown
          end
        end

        module_function :context_window_for, :max_tokens_for, :critical_capabilities_for, :pricing_for, :model_family
      end
    end
  end
end
