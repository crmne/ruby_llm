# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Determines capabilities and pricing for Anthropic models
      module Capabilities
        module_function

        # Determines the context window size for a given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def determine_context_window(_model_id)
          # All Claude 3 and 3.5 and 3.7 models have 200K token context windows
          200_000
        end

        # Determines the maximum output tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def determine_max_tokens(model_id)
          case model_id
          when /claude-3-7-sonnet/, /claude-3-5/ then 8_192
          else 4_096
          end
        end

        # Gets the input price per million tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for input
        def get_input_price(model_id)
          PRICES.dig(model_family(model_id), :input) || default_input_price
        end

        # Gets the output price per million tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for output
        def get_output_price(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        # Determines if a model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          # All Claude 3, 3.5, and 3.7 models support vision
          !model_id.match?(/claude-[12]/)
        end

        # Determines if a model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          model_id.match?(/claude-3/)
        end

        # Determines if a model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          model_id.match?(/claude-3/)
        end

        # Determines if a model supports extended thinking
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports extended thinking
        def supports_extended_thinking?(model_id)
          model_id.match?(/claude-3-7-sonnet/)
        end

        # Determines the model family for a given model ID
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id)
          case model_id
          when /claude-3-7-sonnet/  then 'claude-3-7-sonnet'
          when /claude-3-5-sonnet/  then 'claude-3-5-sonnet'
          when /claude-3-5-haiku/   then 'claude-3-5-haiku'
          when /claude-3-opus/      then 'claude-3-opus'
          when /claude-3-sonnet/    then 'claude-3-sonnet'
          when /claude-3-haiku/     then 'claude-3-haiku'
          else 'claude-2'
          end
        end

        # Returns the model type
        # @param model_id [String] the model identifier (unused but kept for API consistency)
        # @return [String] the model type, always 'chat' for Anthropic models
        def model_type(_)
          'chat'
        end

        # Pricing information for Anthropic models (per million tokens)
        PRICES = {
          'claude-3-7-sonnet': { input: 3.0, output: 15.0 },
          'claude-3-5-sonnet': { input: 3.0, output: 15.0 },
          'claude-3-5-haiku': { input: 0.80, output: 4.0 },
          'claude-3-opus': { input: 15.0, output: 75.0 },
          'claude-3-haiku': { input: 0.25, output: 1.25 },
          'claude-2': { input: 3.0, output: 15.0 }
        }.freeze

        # Default input price if model not found in PRICES
        # @return [Float] default price per million tokens for input
        def default_input_price
          3.0
        end

        # Default output price if model not found in PRICES
        # @return [Float] default price per million tokens for output
        def default_output_price
          15.0
        end

        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: ['text']
          }

          # All Claude 3+ models support vision
          unless model_id.match?(/claude-[12]/)
            modalities[:input] << 'image'
            modalities[:input] << 'pdf'
          end

          modalities
        end

        def capabilities_for(model_id)
          capabilities = ['streaming']

          # Function calling for Claude 3+
          if model_id.match?(/claude-3/)
            capabilities << 'function_calling'
            capabilities << 'structured_output'
            capabilities << 'batch'
          end

          # Extended thinking (reasoning) for Claude 3.7
          capabilities << 'reasoning' if model_id.match?(/claude-3-7/)

          # Citations
          capabilities << 'citations' if model_id.match?(/claude-3\.5|claude-3-7/)

          capabilities
        end

        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family.to_sym, { input: default_input_price, output: default_output_price })

          standard_pricing = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }

          # Batch is typically half the price
          batch_pricing = {
            input_per_million: prices[:input] * 0.5,
            output_per_million: prices[:output] * 0.5
          }

          # Add reasoning output pricing for 3.7 models
          if model_id.match?(/claude-3-7/)
            standard_pricing[:reasoning_output_per_million] = prices[:output] * 2.5
            batch_pricing[:reasoning_output_per_million] = prices[:output] * 1.25
          end

          {
            text_tokens: {
              standard: standard_pricing,
              batch: batch_pricing
            }
          }
        end
      end
    end
  end
end
