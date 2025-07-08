# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Determines capabilities and constraints for Cohere models
      module Capabilities
        module_function

        # Model family patterns for Cohere models
        MODEL_PATTERNS = {
          'command-a' => /^c4ai-command-a-|^command-a-/,
          'command-r' => /^command-r(?!7b)/, # Command R and Command R+ but not R7B
          'command-r7b' => /^command-r7b/,
          'command-light' => /^command-light/,
          'command-nightly' => /^command-nightly/,
          'command' => /^command(?!-r|-light|-nightly)/, # Regular command models
          'aya-expanse' => /^c4ai-aya-expanse/,
          'aya-vision' => /^c4ai-aya-vision/,
          'aya' => /^aya(?!-vision|-expanse)/,
          'embed-v4' => /^embed-v4/,
          'embed-english-v3' => /^embed-english-v3/,
          'embed-multilingual-v3' => /^embed-multilingual-v3/,
          'embed-v3' => /^embed-v3/, # Fallback for other v3 models
          'embed-english' => /^embed-english/,
          'embed-multilingual' => /^embed-multilingual/,
          'embed' => /^embed/, # Fallback for other embed models
          'rerank-v3-5' => /^rerank-v3\.5/,
          'rerank-english' => /^rerank-english/,
          'rerank-multilingual' => /^rerank-multilingual/,
          'rerank' => /^rerank/ # Fallback for other rerank models
        }.freeze

        # Normalizes temperature values for Cohere models
        # @param temperature [Float] the temperature value to normalize
        # @param _model [String] the model identifier (unused but kept for API consistency)
        # @return [Float, nil] the normalized temperature value or nil if temperature is nil
        def normalize_temperature(temperature, _model)
          # Cohere accepts temperature values between 0.0 and 2.0
          return nil if temperature.nil?

          temperature.clamp(0.0, 2.0)
        end

        # Determines the context window size for a given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_family(model_id)
          when 'command_a' then 256_000 # Command A has 256k context window
          when 'command_r', 'command_r7b' then 128_000 # Command R models have 128k
          when 'aya_expanse', 'aya_vision' then 16_000 # Aya models have 16k
          when 'aya' then 8_192
          else 4_096 # All other Command and Rerank models have 4k context window
          end
        end

        # Determines the maximum output tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for_model(model_id)
          case model_family(model_id)
          when 'command_a' then 8_192 # Command A has 8k max output
          when 'aya_expanse', 'aya_vision' then 4_000 # Aya models have 4k
          when 'aya' then 2_048
          else 4_096 # All regular Command and Command R models have 4k context window
          end
        end

        # Determines if a model supports streaming responses
        # @param model [String] the model identifier
        # @return [Boolean] true if the model supports streaming
        def supports_streaming?(model)
          # Most Cohere models support streaming
          !model.to_s.match?(/embed|rerank/)
        end

        # Determines if a model supports tool/function calling
        # @param model [String] the model identifier
        # @return [Boolean] true if the model supports tools
        def supports_tools?(model)
          # Command models and Aya Vision support function calling
          model.to_s.match?(/command|aya-vision|aya-expanse/)
        end

        # Determines if a model supports image processing
        # @param model [String] the model identifier
        # @return [Boolean] true if the model supports images
        def supports_images?(model)
          # Aya Vision models support images in chat and Embed v3+ supports image embeddings
          model.to_s.match?(/aya-vision|^embed.*v[34]/)
        end

        # Determines if a model supports embedding generation
        # @param model [String] the model identifier
        # @return [Boolean] true if the model supports embeddings
        def supports_embeddings?(model)
          model.to_s.include?('embed')
        end

        # Determines if a model supports reranking
        # @param model [String] the model identifier
        # @return [Boolean] true if the model supports reranking
        def supports_reranking?(model)
          model.to_s.include?('rerank')
        end

        # Determines if a model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          supports_images?(model_id)
        end

        # Determines if a model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          supports_tools?(model_id)
        end

        # Determines if a model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          # Command models and Aya models support structured output
          model_id.match?(/command|aya-vision|aya-expanse/)
        end

        # Determines if a model supports structured output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports structured output
        def supports_structured_output?(model_id)
          supports_json_mode?(model_id)
        end

        # Determines the model family for a given model ID
        # @param model_id [String] the model identifier
        # @return [String] the model family identifier
        def model_family(model_id)
          MODEL_PATTERNS.each do |family, pattern|
            return family.to_s if model_id.match?(pattern)
          end
          'other'
        end

        # Returns the model type
        # @param model_id [String] the model identifier
        # @return [String] the model type ('chat', 'embedding', or 'rerank')
        def model_type(model_id)
          case model_family(model_id)
          when /embed/ then 'embedding'
          when /rerank/ then 'rerank'
          else 'chat'
          end
        end

        # Pricing information for Cohere models (per million tokens)
        # Source: https://cohere.com/pricing (as of 2025)
        PRICES = {
          command_a: { input: 2.50, output: 10.00 },
          command_r: { input: 0.15, output: 0.60 },
          command_r7b: { input: 0.0375, output: 0.15 },
          command_light: { input: 0.025, output: 0.10 }, # Estimated light model pricing
          command_nightly: { input: 0.15, output: 0.60 }, # Same as command-r for nightly
          command: { input: 0.05, output: 0.20 }, # Regular command model pricing
          aya_expanse: { input: 0.50, output: 1.50 },
          aya_vision: { input: 0.50, output: 1.50 },
          aya: { input: 0.50, output: 1.50 },
          embed_v4: { text_price: 0.12, image_price: 0.47 },
          embed_english_v3: { price: 0.12 },
          embed_multilingual_v3: { price: 0.12 },
          embed_v3: { price: 0.12 },
          embed_english: { price: 0.10 }, # Light models slightly cheaper
          embed_multilingual: { price: 0.10 },
          embed: { price: 0.12 },
          rerank_v3point5: { price: 2.0 },
          rerank_english: { price: 1.50 },
          rerank_multilingual: { price: 2.0 },
          rerank: { price: 2.0 } # $2.00 per 1K searches = $2000 per 1M searches
        }.freeze

        # Gets the input price per million tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for input
        def input_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { input: default_input_price })
          prices[:input] || prices[:text_price] || prices[:price] || default_input_price
        end

        # Gets the output price per million tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens for output
        def output_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { output: default_output_price })
          prices[:output] || prices[:text_price] || prices[:price] || default_output_price
        end

        # Gets the image price per million tokens for a given model
        # @param model_id [String] the model identifier
        # @return [Float, nil] the price per million tokens for image processing or nil if not supported
        def image_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, {})
          prices[:image_price]
        end

        # Default input price if model not found in PRICES
        # @return [Float] default price per million tokens for input
        def default_input_price
          1.0
        end

        # Default output price if model not found in PRICES
        # @return [Float] default price per million tokens for output
        def default_output_price
          2.0
        end

        # Returns the supported modalities for a given model
        # @param model_id [String] the model identifier
        # @return [Hash] hash containing input and output modalities
        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: ['text']
          }

          modalities[:input] << 'image' if supports_images?(model_id)
          modalities[:output] = ['embeddings'] if supports_embeddings?(model_id)
          modalities[:output] = ['rerank'] if supports_reranking?(model_id)

          modalities
        end

        # Returns the capabilities of a given model
        # @param model_id [String] the model identifier
        # @return [Array<String>] array of capability strings
        def capabilities_for(model_id)
          capabilities = []

          capabilities << 'streaming' if supports_streaming?(model_id)
          capabilities << 'reranking' if supports_reranking?(model_id)
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_structured_output?(model_id)
          capabilities << 'multilingual' if model_id.match?(/aya|multilingual/)
          capabilities << 'citations' if model_id.match?(/command-a|aya-vision|aya-expanse/)

          capabilities
        end

        # Returns the pricing structure for a given model
        # @param model_id [String] the model identifier
        # @return [Hash] hash containing pricing information
        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family.to_sym, { input: default_input_price, output: default_output_price })

          if prices[:price]
            # For models with single pricing (like older embeddings and rerank)
            { usage_tokens: { standard: { price_per_million: prices[:price] } } }
          elsif prices[:text_price]
            # For models with text/image pricing (like embed-v4)
            pricing_structure = {
              text_tokens: { standard: { price_per_million: prices[:text_price] } }
            }

            # Add image pricing if available
            if prices[:image_price]
              pricing_structure[:image_tokens] = {
                standard: { price_per_million: prices[:image_price] }
              }
            end

            pricing_structure
          else
            # For models with input/output pricing
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

        # Formats a model ID for display purposes
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          model_id.gsub(/^c4ai-/, '')
                  .tr('-', ' ')
                  .split
                  .map(&:capitalize)
                  .join(' ')
        end
      end
    end
  end
end
