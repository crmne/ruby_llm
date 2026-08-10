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
          sonar_reasoning_pro: { input: 2.0, output: 8.0 },
          sonar_deep_research: {
            input: 2.0,
            output: 8.0,
            reasoning_output: 3.0
          },
          pplx_embed_small: { input: 0.004 },
          pplx_embed_large: { input: 0.03 }
        }.freeze

        def embedding_model?(model_id)
          model_id.start_with?('pplx-embed')
        end

        def context_window_for(model_id)
          return 32_768 if embedding_model?(model_id)

          model_id.match?(/sonar-pro/) ? 200_000 : 128_000
        end

        def max_tokens_for(model_id)
          return nil if embedding_model?(model_id)

          model_id.match?(/sonar-(?:pro|reasoning-pro)/) ? 8_192 : 4_096
        end

        def critical_capabilities_for(model_id)
          return [] if embedding_model?(model_id)

          # Every Perplexity search model returns search result citations.
          capabilities = ['citations']
          capabilities << 'vision' if model_id.match?(/sonar(?:-pro|-reasoning(?:-pro)?)?$/)
          capabilities << 'reasoning' if model_id.match?(/reasoning|deep-research/)
          capabilities
        end

        def pricing_for(model_id)
          prices = PRICES.fetch(model_family(model_id), { input: 1.0, output: 1.0 })

          standard = { input_per_million: prices[:input] }
          standard[:output_per_million] = prices[:output] if prices[:output]
          standard[:reasoning_output_per_million] = prices[:reasoning_output] if prices[:reasoning_output]

          { text_tokens: { standard: standard } }
        end

        def model_family(model_id)
          case model_id
          when 'sonar' then :sonar
          when 'sonar-pro' then :sonar_pro
          when 'sonar-reasoning-pro' then :sonar_reasoning_pro
          when 'sonar-deep-research' then :sonar_deep_research
          when 'pplx-embed-v1-0.6b' then :pplx_embed_small
          when 'pplx-embed-v1-4b' then :pplx_embed_large
          else :unknown
          end
        end

        module_function :embedding_model?, :context_window_for, :max_tokens_for, :critical_capabilities_for,
                        :pricing_for, :model_family
      end
    end
  end
end
