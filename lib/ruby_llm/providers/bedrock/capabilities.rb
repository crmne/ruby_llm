# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Determines capabilities and pricing for AWS Bedrock models
      module Capabilities
        module_function

        # Returns the context window size for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /anthropic\.claude-2/ then 100_000
          else 200_000
          end
        end

        # Returns the maximum output tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(_model_id)
          4_096
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

        # Determines if the model supports chat capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports chat
        def supports_chat?(model_id)
          model_id.match?(/anthropic\.claude/)
        end

        # Determines if the model supports streaming capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports streaming
        def supports_streaming?(model_id)
          model_id.match?(/anthropic\.claude/)
        end

        # Determines if the model supports image input/output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports images
        def supports_images?(model_id)
          model_id.match?(/anthropic\.claude/)
        end

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          model_id.match?(/anthropic\.claude/)
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          model_id.match?(/anthropic\.claude/)
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
          model_id.match?(/anthropic\.claude/)
        end

        # Formats the model ID into a human-readable display name
        # @param model_id [String] the model identifier
        # @return [String] the formatted display name
        def format_display_name(model_id)
          model_id.then { |id| humanize(id) }
        end

        # Determines the type of model
        # @param model_id [String] the model identifier
        # @return [String] the model type (chat, embedding, image, audio)
        def model_type(_model_id)
          'chat'
        end

        # Determines if the model supports structured output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports structured output
        def supports_structured_output?(model_id)
          model_id.match?(/anthropic\.claude/)
        end

        # Model family patterns for capability lookup
        MODEL_FAMILIES = {
          /anthropic\.claude-3-opus/ => :claude3_opus,
          /anthropic\.claude-3-sonnet/ => :claude3_sonnet,
          /anthropic\.claude-3-5-sonnet/ => :claude3_sonnet,
          /anthropic\.claude-3-7-sonnet/ => :claude3_sonnet,
          /anthropic\.claude-3-haiku/ => :claude3_haiku,
          /anthropic\.claude-3-5-haiku/ => :claude3_5_haiku,
          /anthropic\.claude-v2/ => :claude2,
          /anthropic\.claude-instant/ => :claude_instant
        }.freeze

        # Determines the model family for pricing and capability lookup
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id)
          MODEL_FAMILIES.find { |pattern, _family| model_id.match?(pattern) }&.last || :other
        end

        # Pricing information for Bedrock models (per million tokens)
        PRICES = {
          claude3_opus: { input: 15.0, output: 75.0 },
          claude3_sonnet: { input: 3.0, output: 15.0 },
          claude3_haiku: { input: 0.25, output: 1.25 },
          claude3_5_haiku: { input: 0.8, output: 4.0 },
          claude2: { input: 8.0, output: 24.0 },
          claude_instant: { input: 0.8, output: 2.4 }
        }.freeze

        # Default input price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_input_price
          0.1
        end

        # Default output price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_output_price
          0.2
        end

        # Converts a model ID to a human-readable format
        # @param id [String] the model identifier
        # @return [String] the humanized model name
        def humanize(id)
          id.tr('-', ' ')
            .split('.')
            .last
            .split
            .map(&:capitalize)
            .join(' ')
        end

        def modalities_for(model_id)
          modalities = {
            input: ['text'],
            output: ['text']
          }

          # Vision support for Claude models
          if model_id.match?(/anthropic\.claude/) && supports_vision?(model_id)
            modalities[:input] << 'image'
            modalities[:input] << 'pdf'
          end

          modalities
        end

        def capabilities_for(model_id)
          capabilities = []

          # Streaming
          capabilities << 'streaming' if model_id.match?(/anthropic\.claude/)

          # Function calling & structured output
          capabilities << 'function_calling' if supports_functions?(model_id)

          capabilities << 'structured_output' if supports_json_mode?(model_id)

          # Extended thinking for 3.7 models
          capabilities << 'reasoning' if model_id.match?(/claude-3-7/)

          # Batch capabilities for newer Claude models
          if model_id.match?(/claude-3\.5|claude-3-7/)
            capabilities << 'batch'
            capabilities << 'citations'
          end

          capabilities
        end

        def pricing_for(model_id)
          family = model_family(model_id)
          prices = PRICES.fetch(family, { input: default_input_price, output: default_output_price })

          standard_pricing = {
            input_per_million: prices[:input],
            output_per_million: prices[:output]
          }

          # Batch pricing - typically 50% of standard
          batch_pricing = {
            input_per_million: prices[:input] * 0.5,
            output_per_million: prices[:output] * 0.5
          }

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
