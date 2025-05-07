# frozen_string_literal: true

module RubyLLM
  module Providers
    module DeepSeek
      # Determines capabilities and pricing for DeepSeek models
      module Capabilities
        module_function

        # Returns the context window size for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /deepseek-(?:chat|reasoner)/ then 64_000
          else 32_768 # Sensible default
          end
        end

        # Returns the maximum number of tokens that can be generated
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum number of tokens
        def max_tokens_for(model_id)
          case model_id
          when /deepseek-(?:chat|reasoner)/ then 8_192
          else 4_096 # Default if max_tokens not specified
          end
        end

        # Returns the price per million tokens for input (cache miss)
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def input_price_for(model_id)
          PRICES.dig(model_family(model_id), :input_miss) || default_input_price
        end

        # Returns the price per million tokens for output
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def output_price_for(model_id)
          PRICES.dig(model_family(model_id), :output) || default_output_price
        end

        # Returns the price per million tokens for input with cache hit
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def cache_hit_price_for(model_id)
          PRICES.dig(model_family(model_id), :input_hit) || default_cache_hit_price
        end

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(_model_id)
          false # DeepSeek models don't currently support vision
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports function calling
        def supports_functions?(model_id)
          model_id.match?(/deepseek-chat/) # Only deepseek-chat supports function calling
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(_model_id)
          false # DeepSeek function calling is unstable
        end

        # Returns a formatted display name for the model
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          case model_id
          when 'deepseek-chat' then 'DeepSeek V3'
          when 'deepseek-reasoner' then 'DeepSeek R1'
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
          'chat' # All DeepSeek models are chat models
        end

        # Returns the model family
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family
        def model_family(model_id)
          case model_id
          when /deepseek-reasoner/ then :reasoner
          else :chat # Default to chat family
          end
        end

        # Pricing information for DeepSeek models (USD per 1M tokens)
        PRICES = {
          chat: {
            input_hit: 0.07,   # $0.07 per million tokens on cache hit
            input_miss: 0.27,  # $0.27 per million tokens on cache miss
            output: 1.10       # $1.10 per million tokens output
          },
          reasoner: {
            input_hit: 0.14,   # $0.14 per million tokens on cache hit
            input_miss: 0.55,  # $0.55 per million tokens on cache miss
            output: 2.19       # $2.19 per million tokens output
          }
        }.freeze

        # Default input price when model family can't be determined
        # @return [Float] the default input price
        def default_input_price
          0.27 # Default to chat cache miss price
        end

        # Default output price when model family can't be determined
        # @return [Float] the default output price
        def default_output_price
          1.10 # Default to chat output price
        end

        # Default cache hit price when model family can't be determined
        # @return [Float] the default cache hit price
        def default_cache_hit_price
          0.07 # Default to chat cache hit price
        end

        def modalities_for(_model_id)
          {
            input: ['text'],
            output: ['text']
          }
        end

        def capabilities_for(model_id)
          capabilities = ['streaming']

          # Function calling for chat models
          capabilities << 'function_calling' if model_id.match?(/deepseek-chat/)

          capabilities
        end

        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family, { input_miss: default_input_price, output: default_output_price })

          standard_pricing = {
            input_per_million: prices[:input_miss],
            output_per_million: prices[:output]
          }

          # Add cached pricing if available
          standard_pricing[:cached_input_per_million] = prices[:input_hit] if prices[:input_hit]

          {
            text_tokens: {
              standard: standard_pricing
            }
          }
        end
      end
    end
  end
end
