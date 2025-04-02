# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Determines capabilities for Ollama
      module Capabilities
        module_function

        # FIXME: none of these facts are available from the Ollama server,
        # or from the Ollama library (https://ollama.com/library) in a structured way.

        # Returns the context window size (input token limit) for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(_model_id)
          # FIXME: placeholder
          4_192 # Sensible (and conservative) default for unknown models
        end

        # Returns the maximum output tokens for the given model
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(_model_id)
          # FIXME: placeholder
          32_768
        end

        # Determines if the model supports vision (image/video) inputs
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision inputs
        def supports_vision?(_model_id)
          # FIXME: placeholder
          false
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports function calling
        def supports_functions?(_model_id)
          # FIXME: placeholder
          true
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(_model_id)
          # FIXME: placeholder
          false
        end

        # Returns the type of model (chat, embedding, image)
        # @param model_id [String] the model identifier
        # @return [String] the model type
        def model_type(_model_id)
          # FIXME: placeholder
          'chat'
        end
      end
    end
  end
end
