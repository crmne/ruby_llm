# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Determines capabilities and pricing for Google Gemini models
      module Capabilities
        module_function

        # Returns the context window size (input token limit) for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/, /gemini-2\.0-flash/, /gemini-2\.0-flash-lite/, /gemini-1\.5-flash/, /gemini-1\.5-flash-8b/ # rubocop:disable Layout/LineLength
            1_048_576
          when /gemini-1\.5-pro/ then 2_097_152
          when /gemini-embedding-exp/ then 8_192
          when /text-embedding-004/, /embedding-001/ then 2_048
          when /aqa/ then 7_168
          when /imagen-3/ then nil # No token limit for image generation
          else 32_768 # Sensible default for unknown models
          end
        end

        # Returns the maximum output tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/ then 64_000
          when /gemini-2\.0-flash/, /gemini-2\.0-flash-lite/, /gemini-1\.5-flash/, /gemini-1\.5-flash-8b/, /gemini-1\.5-pro/ # rubocop:disable Layout/LineLength
            8_192
          when /gemini-embedding-exp/ then nil # Elastic, supports 3072, 1536, or 768
          when /text-embedding-004/, /embedding-001/ then 768 # Output dimension size for embeddings
          when /aqa/ then 1_024
          when /imagen-3/ then 4 # Output images
          else 4_096 # Sensible default
          end
        end

        # Returns the input price per million tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def input_price_for(model_id)
          base_price = PRICES.dig(pricing_family(model_id), :input) || default_input_price
          return base_price unless long_context_model?(model_id)

          # Apply different pricing for prompts longer than 128k tokens
          context_window_for(model_id) > 128_000 ? base_price * 2 : base_price
        end

        # Returns the output price per million tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def output_price_for(model_id)
          base_price = PRICES.dig(pricing_family(model_id), :output) || default_output_price
          return base_price unless long_context_model?(model_id)

          # Apply different pricing for prompts longer than 128k tokens
          context_window_for(model_id) > 128_000 ? base_price * 2 : base_price
        end

        # Determines if the model supports vision (image/video) inputs
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision inputs
        def supports_vision?(model_id)
          return false if model_id.match?(/text-embedding|embedding-001|aqa/)

          model_id.match?(/gemini|flash|pro|imagen/)
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports function calling
        def supports_functions?(model_id)
          return false if model_id.match?(/text-embedding|embedding-001|aqa|flash-lite|imagen|gemini-2\.0-flash-lite/)

          model_id.match?(/gemini|pro|flash/)
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          if model_id.match?(/text-embedding|embedding-001|aqa|imagen|gemini-2\.0-flash-lite|gemini-2\.5-pro-exp-03-25/)
            return false
          end

          model_id.match?(/gemini|pro|flash/)
        end

        # Formats the model ID into a human-readable display name
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          model_id
            .delete_prefix('models/')
            .split('-')
            .map(&:capitalize)
            .join(' ')
            .gsub(/(\d+\.\d+)/, ' \1') # Add space before version numbers
            .gsub(/\s+/, ' ')          # Clean up multiple spaces
            .gsub('Aqa', 'AQA')        # Special case for AQA
            .strip
        end

        # Determines if the model supports context caching
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports caching
        def supports_caching?(model_id)
          if model_id.match?(/flash-lite|gemini-2\.5-pro-exp-03-25|aqa|imagen|text-embedding|embedding-001/)
            return false
          end

          model_id.match?(/gemini|pro|flash/)
        end

        # Determines if the model supports tuning
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports tuning
        def supports_tuning?(model_id)
          model_id.match?(/gemini-1\.5-flash|gemini-1\.5-flash-8b/)
        end

        # Determines if the model supports audio inputs
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports audio inputs
        def supports_audio?(model_id)
          model_id.match?(/gemini|pro|flash/)
        end

        # Returns the type of model (chat, embedding, image)
        # @param model_id [String] the model identifier
        # @return [String] the model type
        def model_type(model_id)
          case model_id
          when /text-embedding|embedding|gemini-embedding/ then 'embedding'
          when /imagen/ then 'image'
          else 'chat'
          end
        end

        # Returns the model family identifier
        # @param model_id [String] the model identifier
        # @return [String] the model family identifier
        def model_family(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/ then 'gemini25_pro_exp'
          when /gemini-2\.0-flash-lite/ then 'gemini20_flash_lite'
          when /gemini-2\.0-flash/ then 'gemini20_flash'
          when /gemini-1\.5-flash-8b/ then 'gemini15_flash_8b'
          when /gemini-1\.5-flash/ then 'gemini15_flash'
          when /gemini-1\.5-pro/ then 'gemini15_pro'
          when /gemini-embedding-exp/ then 'gemini_embedding_exp'
          when /text-embedding-004/ then 'embedding4'
          when /embedding-001/ then 'embedding1'
          when /aqa/ then 'aqa'
          when /imagen-3/ then 'imagen3'
          else 'other'
          end
        end

        # Returns the pricing family identifier for the model
        # @param model_id [String] the model identifier
        # @return [Symbol] the pricing family identifier
        def pricing_family(model_id)
          case model_id
          when /gemini-2\.5-pro-exp-03-25/ then :pro_2_5 # rubocop:disable Naming/VariableNumber
          when /gemini-2\.0-flash-lite/ then :flash_lite_2 # rubocop:disable Naming/VariableNumber
          when /gemini-2\.0-flash/ then :flash_2 # rubocop:disable Naming/VariableNumber
          when /gemini-1\.5-flash-8b/ then :flash_8b
          when /gemini-1\.5-flash/ then :flash
          when /gemini-1\.5-pro/ then :pro
          when /gemini-embedding-exp/ then :gemini_embedding
          when /text-embedding|embedding/ then :embedding
          when /imagen/ then :imagen
          when /aqa/ then :aqa
          else :base
          end
        end

        # Determines if the model supports long context
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports long context
        def long_context_model?(model_id)
          model_id.match?(/gemini-1\.5-(?:pro|flash)|gemini-1\.5-flash-8b/)
        end

        # Returns the context length for the model
        # @param model_id [String] the model identifier
        # @return [Integer] the context length in tokens
        def context_length(model_id)
          context_window_for(model_id)
        end

        # Pricing information for Gemini models (per 1M tokens in USD)
        PRICES = {
          flash_2: { # Gemini 2.0 Flash # rubocop:disable Naming/VariableNumber
            input: 0.10,
            output: 0.40,
            audio_input: 0.70,
            cache: 0.025,
            cache_storage: 1.00,
            grounding_search: 35.00 # per 1K requests after 1.5K free
          },
          flash_lite_2: { # Gemini 2.0 Flash Lite # rubocop:disable Naming/VariableNumber
            input: 0.075,
            output: 0.30
          },
          flash: { # Gemini 1.5 Flash
            input: 0.075,
            output: 0.30,
            cache: 0.01875,
            cache_storage: 1.00,
            grounding_search: 35.00 # per 1K requests up to 5K per day
          },
          flash_8b: { # Gemini 1.5 Flash 8B
            input: 0.0375,
            output: 0.15,
            cache: 0.01,
            cache_storage: 0.25,
            grounding_search: 35.00 # per 1K requests up to 5K per day
          },
          pro: { # Gemini 1.5 Pro
            input: 1.25,
            output: 5.0,
            cache: 0.3125,
            cache_storage: 4.50,
            grounding_search: 35.00 # per 1K requests up to 5K per day
          },
          pro_2_5: { # Gemini 2.5 Pro Experimental # rubocop:disable Naming/VariableNumber
            input: 0.12,
            output: 0.50
          },
          gemini_embedding: { # Gemini Embedding Experimental
            input: 0.002,
            output: 0.004
          },
          embedding: { # Text Embedding models
            input: 0.00,
            output: 0.00
          },
          imagen: { # Imagen 3
            price: 0.03 # per image
          },
          aqa: { # AQA model
            input: 0.00,
            output: 0.00
          }
        }.freeze

        # Default input price for unknown models
        # @return [Float] the default input price per million tokens
        def default_input_price
          0.075 # Default to Flash pricing
        end

        # Default output price for unknown models
        # @return [Float] the default output price per million tokens
        def default_output_price
          0.30 # Default to Flash pricing
        end

        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: ['text']
          }

          # Vision support
          if supports_vision?(model_id)
            modalities[:input] << 'image'
            modalities[:input] << 'pdf'
          end

          # Audio support
          modalities[:input] << 'audio' if model_id.match?(/audio/)

          # Embedding output
          modalities[:output] << 'embeddings' if model_id.match?(/embedding|gemini-embedding/)

          modalities
        end

        def capabilities_for(model_id)
          capabilities = ['streaming']

          # Function calling
          capabilities << 'function_calling' if supports_functions?(model_id)

          # JSON mode
          capabilities << 'structured_output' if supports_json_mode?(model_id)

          # Batch processing
          capabilities << 'batch' if model_id.match?(/embedding|flash/)

          # Caching
          capabilities << 'caching' if supports_caching?(model_id)

          # Tuning
          capabilities << 'fine_tuning' if supports_tuning?(model_id)

          capabilities
        end

        def pricing_for(model_id)
          family = pricing_family(model_id)
          prices = PRICES.fetch(family, { input: default_input_price, output: default_output_price })

          standard_pricing = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }

          # Add cached pricing if available
          standard_pricing[:cached_input_per_million] = prices[:input_hit] if prices[:input_hit]

          # Batch pricing (typically 50% discount)
          batch_pricing = {
            input_per_million: (standard_pricing[:input_per_million] || 0) * 0.5,
            output_per_million: (standard_pricing[:output_per_million] || 0) * 0.5
          }

          if standard_pricing[:cached_input_per_million]
            batch_pricing[:cached_input_per_million] = standard_pricing[:cached_input_per_million] * 0.5
          end

          pricing = {
            text_tokens: {
              standard: standard_pricing,
              batch: batch_pricing
            }
          }

          # Add embedding pricing if applicable
          if model_id.match?(/embedding|gemini-embedding/)
            pricing[:embeddings] = {
              standard: { input_per_million: prices[:price] || 0.002 }
            }
          end

          pricing
        end
      end
    end
  end
end
