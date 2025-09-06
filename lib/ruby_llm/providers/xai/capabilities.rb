# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Determines capabilities and pricing for xAI (Grok) models
      # - https://docs.x.ai/docs/models
      module Capabilities
        module_function

        # rubocop:disable Naming/VariableNumber
        MODEL_PATTERNS = {
          grok_2: /^grok-2(?!-vision)/,
          grok_2_vision: /^grok-2-vision/,
          grok_2_image: /^grok-2-image/,
          grok_3: /^grok-3(?!-(?:fast|mini))/,
          grok_3_fast: /^grok-3-fast/,
          grok_3_mini: /^grok-3-mini(?!-fast)/,
          grok_3_mini_fast: /^grok-3-mini-fast/,
          grok_4: /^grok-4/
        }.freeze
        # rubocop:enable Naming/VariableNumber

        def context_window_for(model_id)
          case model_family(model_id)
          when 'grok_4' then 256_000
          when 'grok_2_vision' then 32_768
          else 131_072
          end
        end

        def max_tokens_for(_model_id)
          4_096
        end

        def supports_vision?(model_id)
          case model_family(model_id)
          when 'grok_2_vision' then true
          else false
          end
        end

        def supports_functions?(model_id)
          model_family(model_id) != 'grok_2_image'
        end

        def supports_structured_output?(model_id)
          model_family(model_id) != 'grok_2_image'
        end

        def supports_json_mode?(model_id)
          supports_structured_output?(model_id)
        end

        # Pricing from API data (per million tokens)
        # rubocop:disable Naming/VariableNumber
        PRICES = {
          grok_2: { input: 2.0, output: 10.0 },
          grok_2_vision: { input: 2.0, output: 10.0 },
          grok_3: { input: 3.0, output: 15.0, cached_input: 0.75 },
          grok_3_fast: { input: 5.0, output: 25.0, cached_input: 1.25 },
          grok_3_mini: { input: 0.3, output: 0.5, cached_input: 0.075 },
          grok_3_mini_fast: { input: 0.6, output: 4.0, cached_input: 0.15 },
          grok_4: { input: 3.0, output: 15.0, cached_input: 0.75 }
        }.freeze
        # rubocop:enable Naming/VariableNumber

        def model_family(model_id)
          MODEL_PATTERNS.each do |family, pattern|
            return family.to_s if model_id.match?(pattern)
          end
          'other'
        end

        def input_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { input: default_input_price })
          prices[:input] || default_input_price
        end

        def cached_input_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, {})
          prices[:cached_input]
        end

        def output_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { output: default_output_price })
          prices[:output] || default_output_price
        end

        def model_type(model_id)
          return 'image' if model_family(model_id) == 'grok_2_image'

          'chat'
        end

        def default_input_price
          2.0
        end

        def default_output_price
          10.0
        end

        def format_display_name(model_id)
          model_id.then { |id| humanize(id) }
                  .then { |name| apply_special_formatting(name) }
        end

        def humanize(id)
          id.tr('-', ' ')
            .split
            .map(&:capitalize)
            .join(' ')
        end

        def apply_special_formatting(name)
          name
            .gsub(/^Grok /, 'Grok-')
            .gsub(/(\d{4}) (\d{2}) (\d{2})/, '\1-\2-\3')
        end

        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: []
          }

          modalities[:output] << 'text' if model_type(model_id) == 'chat'

          # Vision support
          modalities[:input] << 'image' if supports_vision?(model_id)

          modalities
        end

        def capabilities_for(model_id)
          capabilities = []

          # Common capabilities
          capabilities << 'streaming'
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_structured_output?(model_id)

          capabilities
        end

        def pricing_for(model_id)
          standard_pricing = {
            input_per_million: input_price_for(model_id),
            output_per_million: output_price_for(model_id)
          }

          # Add cached pricing if available
          cached_price = cached_input_price_for(model_id)
          standard_pricing[:cached_input_per_million] = cached_price if cached_price

          # Pricing structure
          { text_tokens: { standard: standard_pricing } }
        end
      end
    end
  end
end
