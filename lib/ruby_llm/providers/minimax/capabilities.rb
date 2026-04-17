# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # Determines capabilities and pricing for MiniMax models
      module Capabilities
        module_function

        def context_window_for(model_id)
          case model_id
          when /M2\.7/ then 1_000_000
          when /M2\.5/ then 204_000
          else 204_000
          end
        end

        def max_tokens_for(model_id)
          case model_id
          when /M2\.7/ then 16_384
          when /M2\.5/ then 16_384
          else 8_192
          end
        end

        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input) || default_input_price
        end

        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        def supports_vision?(_model_id)
          false
        end

        def supports_functions?(model_id)
          model_id.match?(/M2\.[57]/)
        end

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          false
        end

        def supports_json_mode?(model_id)
          model_id.match?(/M2\.[57]/)
        end

        def format_display_name(model_id)
          model_id
        end

        def model_type(_model_id)
          'chat'
        end

        def model_family(model_id)
          case model_id
          when /M2\.7-highspeed/ then :m2_7_highspeed
          when /M2\.7/ then :m2_7
          when /M2\.5-highspeed/ then :m2_5_highspeed
          when /M2\.5/ then :m2_5
          else :default
          end
        end

        PRICES = {
          m2_7: {
            input: 0.10,
            output: 0.10
          },
          m2_7_highspeed: {
            input: 0.07,
            output: 0.07
          },
          m2_5: {
            input: 0.10,
            output: 0.10
          },
          m2_5_highspeed: {
            input: 0.07,
            output: 0.07
          }
        }.freeze

        def default_input_price
          0.10
        end

        def default_output_price
          0.10
        end

        def modalities_for(_model_id)
          {
            input: ['text'],
            output: ['text']
          }
        end

        def capabilities_for(model_id)
          capabilities = ['streaming']
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'json_mode' if supports_json_mode?(model_id)
          capabilities
        end

        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family, { input: default_input_price, output: default_output_price })

          {
            text_tokens: {
              standard: {
                input_per_million: prices[:input],
                output_per_million: prices[:output]
              }
            }
          }
        end
      end
    end
  end
end
