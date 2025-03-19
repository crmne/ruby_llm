# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Defines capabilities and pricing for AWS Bedrock models
      module Capabilities
        module_function

        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input) || default_input_price
        end

        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        def supports_vision?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def supports_functions?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def supports_audio?(_model_id)
          false
        end

        def supports_json_mode?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def format_display_name(model_id)
          case model_id
          when /anthropic\.claude-3/
            'Claude 3'
          when /anthropic\.claude-v2/
            'Claude 2'
          when /anthropic\.claude-instant/
            'Claude Instant'
          when /amazon\.titan/
            'Titan'
          else
            model_id
          end
        end

        def model_type(_model_id)
          'chat'
        end

        def supports_structured_output?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def model_family(model_id)
          case model_id
          when /anthropic\.claude-3/
            :claude3
          when /anthropic\.claude-v2/
            :claude2
          when /anthropic\.claude-instant/
            :claude_instant
          when /amazon\.titan/
            :titan
          else
            :other
          end
        end

        def context_window_for(model_id)
          case model_id
          when /anthropic\.claude-3/
            200_000
          when /anthropic\.claude-v2/
            100_000
          when /anthropic\.claude-instant/
            100_000
          when /amazon\.titan/
            8_000
          else
            4_096
          end
        end

        def max_tokens_for(model_id)
          case model_id
          when /anthropic\.claude-3/
            4_096
          when /anthropic\.claude-v2/
            4_096
          when /anthropic\.claude-instant/
            2_048
          when /amazon\.titan/
            4_096
          else
            2_048
          end
        end

        private

        PRICES = {
          claude3: { input: 15.0, output: 75.0 },
          claude2: { input: 8.0, output: 24.0 },
          claude_instant: { input: 0.8, output: 2.4 },
          titan: { input: 0.1, output: 0.2 }
        }.freeze

        def default_input_price
          0.1
        end

        def default_output_price
          0.2
        end
      end
    end
  end
end 