module RubyLLM
  module Providers
    module Mistral
      # Determines capabilities and pricing for Mistral models
      module Capabilities
        module_function

        # Returns the context window size for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /mistral-large-2411/ then 131_000
          when /mistral-small-latest/ then 32_000
          when /mistral-medium-latest/ then 32_000
          when /ministral-3b-latest/ then 131_000
          when /ministral-8b-latest/ then 131_000
          when /codestral-2501/ then 256_000
          when /pixtral-large-latest/ then 131_000
          when /mistral-saba-latest/ then 32_000
          when /mistral-embed/ then 8_000
          when /mistral-moderation-latest/ then 8_000
          when /codestral-mamba-latest/ then 1_000_000 # Using a large number for "Infinite-length"
          else 32_000 # Default to smallest common size
          end
        end

        # Returns the maximum output tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(model_id)
          # Generally, max output tokens is slightly less than context window
          (context_window_for(model_id) * 0.9).to_i
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

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          # Explicitly match the known vision-capable models
          vision_models = [
            'pixtral-12b',
            'pixtral-large',
            'mistral-medium',
            'mistral-small'
          ]
          model_id = model_id.to_s.split('/').last
          result = vision_models.any? { |id| model_id.match?(/^#{Regexp.escape(id)}/) }
          result
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          function_calling_models = [
            'mistral-large',
            'mistral-medium',
            'mistral-small',
            'codestral',
            'ministral-8b',
            'ministral-3b',
            'pixtral-12b',
            'pixtral-large',
            'mistral-nemo'
          ]
          model_id = model_id.to_s.split('/').last
          result = function_calling_models.any? { |id| model_id.match?(/^#{Regexp.escape(id)}/) }
          result
        end

        # Determines if the model supports audio input/output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports audio
        def supports_audio?(_model_id)
          false
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          !model_id.match?(/embed|moderation/)
        end

        # Formats the model ID into a human-readable display name
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          model_id.then { |id| humanize(id) }
                  .then { |name| apply_special_formatting(name) }
        end

        # Determines the type of model
        # @param model_id [String] the model identifier
        # @return [String] the model type (chat, embedding, moderation)
        def model_type(model_id)
          case model_id
          when /embed/ then "embedding"
          when /moderation/ then "moderation"
          else "chat"
          end
        end

        # Determines if the model supports structured output
        # based on the docs in https://docs.mistral.ai/capabilities/structured-output/structured_output_overview/ all mistral models support JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports structured output
        def supports_structured_output?(model_id)
          true
        end

        # Determines the model family for pricing and capability lookup
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id)
          case model_id
          when /mistral-large/ then "large"
          when /mistral-small/ then "small"
          when /codestral/ then "codestral"
          when /pixtral/ then "pixtral"
          when /mistral-nemo/ then "nemo"
          when /embed/ then "embedding"
          else "other"
          end
        end

        # Pricing information for Mistral models (per million tokens)
        PRICES = {
          "large" => { input: 2.00, output: 6.00 },
          "small" => { input: 0.20, output: 0.60 },
          "codestral" => { input: 0.30, output: 0.90 },
          "pixtral" => { input: 0.15, output: 0.15 },
          "nemo" => { input: 0.15, output: 0.15 },
          "embedding" => { price: 0.1 },
        }.freeze

        # Default input price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_input_price
          0.20 # Default to small model pricing
        end

        # Default output price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_output_price
          0.60 # Default to small model pricing
        end

        # Converts a model ID to a human-readable format
        # @param id [String] the model identifier
        # @return [String] the humanized model name
        def humanize(id)
          id.tr("-", " ")
            .split
            .map(&:capitalize)
            .join(" ")
        end

        # Applies special formatting rules to model names
        # @param name [String] the humanized model name
        # @return [String] the specially formatted model name
        def apply_special_formatting(name)
          name
            .gsub("Mistral ", "Mistral-")
            .gsub("Ministral ", "Ministral-")
            .gsub("Codestral ", "Codestral-")
            .gsub("Pixtral ", "Pixtral-")
            .gsub("Mathstral ", "Mathstral-")
            .gsub("Embed ", "Embed-")
        end

        def capabilities_for(model_id)
          capabilities = ['streaming']
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_json_mode?(model_id)
          # Add more as needed (e.g., 'batch', 'caching', etc.)
          capabilities
        end
      end
    end
  end
end
