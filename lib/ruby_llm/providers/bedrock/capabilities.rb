# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Determines capabilities and pricing for AWS Bedrock models
      module Capabilities # rubocop:disable Metrics/ModuleLength
        module_function

        # Returns the context window size for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /anthropic\.claude-3-opus/ then 200_000
          when /anthropic\.claude-3-sonnet/ then 200_000
          when /anthropic\.claude-3-haiku/ then 200_000
          when /anthropic\.claude-2/ then 100_000
          when /meta\.llama/ then 4_096
          else 4_096
          end
        end

        # Returns the maximum output tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(model_id)
          case model_id
          when /anthropic\.claude-3/ then 4096
          when /anthropic\.claude-v2/ then 4096
          when /anthropic\.claude-instant/ then 4096
          when /meta\.llama/ then 4096
          when /mistral\./ then 4096
          else 4096
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

        # Determines if the model supports chat capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports chat
        def supports_chat?(model_id)
          case model_id
          when /anthropic\.claude/, /cohere\.command/, /meta\.llama/, /mistral\./
            true
          else
            false
          end
        end

        # Determines if the model supports streaming capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports streaming
        def supports_streaming?(model_id)
          case model_id
          when /anthropic\.claude/, /cohere\.command/, /meta\.llama/, /mistral\./
            true
          else
            false
          end
        end

        # Determines if the model supports image input/output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports images
        def supports_images?(model_id)
          case model_id
          when /anthropic\.claude-3/, /meta\.llama3-2-(?:11b|90b)/
            true
          else
            false
          end
        end

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id)
          case model_id
          when /anthropic\.claude-3/, /meta\.llama3-2-(?:11b|90b)/
            true
          else
            false
          end
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id)
          model_id.match?(/anthropic\.claude-3/)
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
          model_id.match?(/anthropic\.claude-3/)
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
        # @return [String] the model type (chat, embedding, image, audio)
        def model_type(_model_id)
          'chat'
        end

        # Determines if the model supports structured output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports structured output
        def supports_structured_output?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        # Determines the model family for pricing and capability lookup
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id)
          case model_id
          when /anthropic\.claude-3-opus/ then :claude3_opus
          when /anthropic\.claude-3-sonnet/ then :claude3_sonnet
          when /anthropic\.claude-3-haiku/ then :claude3_haiku
          when /anthropic\.claude-v2/ then :claude2
          when /anthropic\.claude-instant/ then :claude_instant
          when /cohere\.command-text/ then :cohere_command
          when /cohere\.command-light/ then :cohere_command_light
          when /meta\.llama.*70b/i then :llama_70b
          when /meta\.llama.*13b/i then :llama_13b
          when /meta\.llama.*7b/i then :llama_7b
          when /mistral\.mistral-7b/ then :mistral_7b
          when /mistral\.mixtral/ then :mistral_mixtral
          when /mistral\.mistral-large/ then :mistral_large
          else :other
          end
        end

        # Pricing information for Bedrock models (per million tokens)
        PRICES = {
          claude3_opus: { input: 15.0, output: 75.0 },
          claude3_sonnet: { input: 3.0, output: 15.0 },
          claude3_haiku: { input: 0.5, output: 2.5 },
          claude2: { input: 8.0, output: 24.0 },
          claude_instant: { input: 0.8, output: 2.4 },
          cohere_command: { input: 1.5, output: 2.0 },
          cohere_command_light: { input: 0.3, output: 0.6 },
          llama_70b: { input: 1.95, output: 2.56 },
          llama_13b: { input: 0.75, output: 1.0 },
          llama_7b: { input: 0.4, output: 0.5 },
          mistral_7b: { input: 0.2, output: 0.2 },
          mistral_mixtral: { input: 0.7, output: 0.7 },
          mistral_large: { input: 2.0, output: 2.0 }
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

        private

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

        # Applies special formatting rules to model names
        # @param name [String] the humanized model name
        # @return [String] the specially formatted model name
        def apply_special_formatting(name)
          name
            .gsub(/Claude (\d)/, 'Claude \1')
            .gsub(/Claude Instant/, 'Claude Instant')
            .gsub(/Llama (\d+)b/i, 'Llama-\1B')
            .gsub(/Mistral (\d+)b/i, 'Mistral-\1B')
            .gsub(/Command Light/, 'Command-Light')
            .gsub(/Command Text/, 'Command')
        end
      end
    end
  end
end 