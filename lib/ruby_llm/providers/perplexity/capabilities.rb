# frozen_string_literal: true

module RubyLLM
  module Providers
    module Perplexity
      # Determines capabilities and pricing for Perplexity models
      module Capabilities
        module_function

        # Returns the context window size for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /sonar-pro/ then 200_000
          else 128_000
          end
        end

        # Returns the maximum output tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(model_id)
          case model_id
          when /sonar-reasoning-pro/, /sonar-pro/ then 8_192
          else 4_096  # Default for other models
          end
        end

        # Returns the input price per million tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for input
        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input) || default_input_price
        end

        # Returns the output price per million tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for output
        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        # Returns the reasoning price per million tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for reasoning
        def reasoning_price_for(model_id)
          PRICES.dig(model_family(model_id), :reasoning) || 0.0
        end

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          # Based on the beta features information
          case model_id
          when /sonar-reasoning-pro/, /sonar-reasoning/, /sonar-pro/, /sonar/ then true
          else false
          end
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(_model_id)
          # Perplexity doesn't seem to support function calling
          false
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(_model_id)
          # Based on the structured outputs beta feature
          true
        end

        # Formats the model ID into a human-readable display name
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          case model_id
          when 'sonar-deep-research' then 'Sonar Deep Research'
          when 'sonar-reasoning-pro' then 'Sonar Reasoning Pro'
          when 'sonar-reasoning' then 'Sonar Reasoning'
          when 'sonar-pro' then 'Sonar Pro'
          when 'sonar' then 'Sonar'
          when 'r1-1776' then 'R1-1776'
          else model_id.tr('-', ' ').split.map(&:capitalize).join(' ')
          end
        end

        # Determines the type of model
        # @param model_id [String] the model identifier
        # @return [String] the model type (chat, embedding, image, audio, moderation)
        def model_type(_model_id)
          'chat'  # All Perplexity models are chat models
        end

        # Determines the model family for pricing and capability lookup
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id)
          case model_id
          when /sonar-deep-research/ then :sonar_deep_research
          when /sonar-reasoning-pro/ then :sonar_reasoning_pro
          when /sonar-reasoning/ then :sonar_reasoning
          when /sonar-pro/ then :sonar_pro
          when /sonar/ then :sonar
          when /r1-1776/ then :r1_1776
          else :other
          end
        end

        # Pricing information for Perplexity models (per million tokens)
        PRICES = {
          sonar_deep_research: { input: 2.0, reasoning: 3.0, output: 8.0 },
          sonar_reasoning_pro: { input: 2.0, output: 8.0 },
          sonar_reasoning: { input: 1.0, output: 5.0 },
          sonar_pro: { input: 3.0, output: 15.0 },
          sonar: { input: 1.0, output: 1.0 },
          r1_1776: { input: 2.0, output: 8.0 }
        }.freeze

        # Default input price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_input_price
          1.0
        end

        # Default output price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_output_price
          1.0
        end
      end
    end
  end
end
