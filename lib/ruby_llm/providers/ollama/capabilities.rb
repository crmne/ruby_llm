# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Determines capabilities for Ollama
      module Capabilities
        module_function

        # Returns the context window size (input token limit) for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(_model_id)
          # FIXME: revise
          4_192 # Sensible (and conservative) default for unknown models
        end

        # Returns the maximum output tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(_model_id)
          # FIXME: revise
          32_768
        end

        # Returns the input price per million tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def input_price_for(_model_id)
          0.0
        end

        # Returns the output price per million tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Float] the price per million tokens in USD
        def output_price_for(_model_id)
          0.0
        end

        # Determines if the model supports vision (image/video) inputs
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision inputs
        def supports_vision?(_model_id)
          # FIXME: revise
          false
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports function calling
        def supports_functions?(_model_id)
          # FIXME: revise
          false
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(_model_id)
          # FIXME: revise
          false
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
            .strip
        end

        # Determines if the model supports context caching
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports caching
        def supports_caching?(_model_id)
          # FIXME: revise
          true
        end

        # Determines if the model supports tuning
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports tuning
        def supports_tuning?(_model_id)
          # FIXME: revise
          false
        end

        # Determines if the model supports audio inputs
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports audio inputs
        def supports_audio?(_model_id)
          # FIXME: revise
          false
        end

        # Returns the type of model (chat, embedding, image)
        # @param model_id [String] the model identifier
        # @return [String] the model type
        def model_type(_model_id)
          # FIXME: revise
          'chat'
        end

        # Returns the model family identifier
        # @param model_id [String] the model identifier
        # @return [String] the model family identifier
        def model_family(_model_id)
          'other'
        end

        # Returns the context length for the model
        # @param model_id [String] the model identifier
        # @return [Integer] the context length in tokens
        def context_length(model_id)
          context_window_for(model_id)
        end

        # Default input price for unknown models
        # @return [Float] the default input price per million tokens
        def default_input_price
          0.0
        end

        # Default output price for unknown models
        # @return [Float] the default output price per million tokens
        def default_output_price
          0.0
        end
      end
    end
  end
end
