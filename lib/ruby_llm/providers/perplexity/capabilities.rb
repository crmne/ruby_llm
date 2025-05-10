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
          when /sonar/ then 128_000
          when /sonar-(?:deep-research|reasoning-pro|reasoning)/ then 128_000
          when /sonar-pro/ then 200_000
          else 128_000 # Sensible default for Perplexity models
          end
        end

        # Returns the maximum number of tokens that can be generated
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum number of tokens
        def max_tokens_for(model_id)
          case model_id
          when /sonar-(?:pro|reasoning-pro)/ then 8_192
          else 4_096 # Default if max_tokens not specified
          end
        end

        # Returns the price per million tokens for input (cache miss)
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input)
        end

        # Returns the price per million tokens for output
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output)
        end

        # Returns the price per million tokens for reasoning
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def reasoning_price_for(model_id)
          PRICES.dig(model_family(model_id), :reasoning) || 0.0
        end

        # Returns the price per 1000 searches for the given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per 1000 searches
        def price_per_1000_searches_for(model_id)
          PRICES.dig(model_family(model_id), :price_per_1000_searches) || 0.0
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
          else
            model_id.split('-')
                    .map(&:capitalize)
                    .join(' ')
          end
        end

        # Returns the model type
        # @param model_id [String] the model identifier
        # @return [String] the model type (e.g., 'chat')
        def model_type(_model_id)
          'chat' # Perplexity models are primarily chat-based
        end

        # Returns the model family
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family
        def model_family(model_id)
          case model_id
          when 'sonar-deep-research' then :sonar_deep_research
          when 'sonar-reasoning-pro' then :sonar_reasoning_pro
          when 'sonar-reasoning'     then :sonar_reasoning
          when 'sonar-pro'           then :sonar_pro
          when 'sonar'               then :sonar
          when 'r1-1776'             then :r1_1776
          else :r1_1776 # Default to smallest family
          end
        end

        # Pricing information for Perplexity models (USD per 1M tokens)
        # Note: Hypothetical pricing based on industry norms; adjust with official rates
        PRICES = {
          sonar_deep_research: {
            input: 2.00,                  # $2.00 per million tokens
            output: 8.00,                 # $8.00 per million tokens
            reasoning: 3.00,              # $3.00 per million tokens
            price_per_1000_searches: 5.00 # $5.00 per 1,000 searches
          },
          sonar_reasoning_pro: {
            input: 2.00,                  # $2.00 per million tokens
            output: 8.00,                 # $8.00 per million tokens
            price_per_1000_searches: 5.00 # $5.00 per 1,000 searches
          },
          sonar_reasoning: {
            input: 1.00,                  # $1.00 per million tokens
            output: 5.00,                 # $5.00 per million tokens
            price_per_1000_searches: 5.00 # $5.00 per 1,000 searches
          },
          sonar_pro: {
            input: 3.00,                  # $3.00 per million tokens
            output: 15.00,                # $15.00 per million tokens
            price_per_1000_searches: 5.00 # $5.00 per 1,000 searches
          },
          sonar: {
            input: 1.00,                  # $1.00 per million tokens
            output: 1.00,                 # $1.00 per million tokens
            price_per_1000_searches: 5.00 # $5.00 per 1,000 searches
          },
          r1_1776: {
            input: 2.00,                  # $2.00 per million tokens
            output: 8.00                  # $8.00 per million tokens
          }
        }.freeze
      end
    end
  end
end
