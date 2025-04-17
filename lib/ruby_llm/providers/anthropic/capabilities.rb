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
          when /claude-3-7-sonnet/  then :claude37_sonnet
          when /claude-3-5-sonnet/  then :claude35_sonnet
          when /claude-3-5-haiku/   then :claude35_haiku
          when /claude-3-opus/      then :claude3_opus
          when /claude-3-sonnet/    then :claude3_sonnet
          when /claude-3-haiku/     then :claude3_haiku
          else :claude2
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
          claude37_sonnet: { input: 3.0, output: 15.0 },
          claude35_sonnet: { input: 3.0, output: 15.0 },
          claude35_haiku: { input: 0.80, output: 4.0 },
          claude3_opus: { input: 15.0, output: 75.0 },
          claude3_haiku: { input: 0.25, output: 1.25 },
          claude2: { input: 3.0, output: 15.0 }
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
      end
    end
  end
end
