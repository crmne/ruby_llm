# frozen_string_literal: true

module RubyLLM
  module Providers
    module OpenAI
      # Determines capabilities and pricing for OpenAI models
      module Capabilities # rubocop:disable Metrics/ModuleLength
        module_function

        # Returns the context window size for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the context window size in tokens
        def context_window_for(model_id)
          case model_id
          when /o1-2024/, /o3-mini/, /o3-mini-2025/ then 200_000
          when /gpt-4o/, /gpt-4o-mini/, /gpt-4-turbo/, /o1-mini/ then 128_000
          when /gpt-4-0[0-9]{3}/ then 8_192
          when /gpt-3.5-turbo$/, /babbage-002/, /davinci-002/, /16k/ then 16_385
          else 4_096
          end
        end

        # Returns the maximum output tokens for the given model ID
        # @param model_id [String] the model identifier
        # @return [Integer] the maximum output tokens
        def max_tokens_for(model_id)
          case model_id
          when /o1-2024/, /o3-mini/, /o3-mini-2025/ then 100_000
          when /o1-mini-2024/ then 65_536
          when /gpt-4o/, /gpt-4o-mini/, /gpt-4o-audio/, /gpt-4o-mini-audio/, /babbage-002/, /davinci-002/ then 16_384
          when /gpt-4-0[0-9]{3}/ then 8_192
          else 4_096
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

        # Determines if the model supports vision capabilities
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports vision
        def supports_vision?(model_id) # rubocop:disable Metrics/MethodLength
          supporting_patterns = [
            /^o1$/,
            /^o1-(?!.*mini|.*preview).*$/,
            /gpt-4\.5/,
            /^gpt-4o$/,
            /gpt-4o-2024/,
            /gpt-4o-search/,
            /^gpt-4o-mini$/,
            /gpt-4o-mini-2024/,
            /gpt-4o-mini-search/,
            /chatgpt-4o/,
            /gpt-4-turbo-2024/,
            /computer-use-preview/,
            /omni-moderation/
          ]
          supporting_patterns.any? { |regex| model_id.match?(regex) }
        end

        # Determines if the model supports function calling
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports functions
        def supports_functions?(model_id) # rubocop:disable Metrics/MethodLength
          supporting_patterns = [
            /^o1$/,
            /gpt-4o/,
            /gpt-4\.5/,
            /chatgpt-4o/,
            /gpt-4-turbo/,
            /computer-use-preview/,
            /o1-preview/,
            /o1-\d{4}-\d{2}-\d{2}/,
            /o1-pro/,
            /o3-mini/
          ]
          supporting_patterns.any? { |regex| model_id.match?(regex) }
        end

        # Determines if the model supports audio input/output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports audio
        def supports_audio?(model_id)
          model_id.match?(/audio-preview|realtime-preview|whisper|tts/)
        end

        # Determines if the model supports JSON mode
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports JSON mode
        def supports_json_mode?(model_id)
          model_id.match?(/gpt-4-\d{4}-preview/) ||
            model_id.include?('turbo') ||
            model_id.match?(/gpt-3.5-turbo-(?!0301|0613)/)
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
        # @return [String] the model type (chat, embedding, image, audio, moderation)
        def model_type(model_id)
          case model_id
          when /text-embedding|embedding/ then 'embedding'
          when /dall-e/ then 'image'
          when /tts|whisper/ then 'audio'
          when /omni-moderation|text-moderation/ then 'moderation'
          else 'chat'
          end
        end

        # Determines if the model supports structured output
        # @param model_id [String] the model identifier
        # @return [Boolean] true if the model supports structured output
        def supports_structured_output?(model_id)
          model_id.match?(/gpt-4o|o[13]-mini|o1|o3-mini/)
        end

        # Determines the model family for pricing and capability lookup
        # @param model_id [String] the model identifier
        # @return [Symbol] the model family identifier
        def model_family(model_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          case model_id
          when /o3-mini/ then 'o3_mini'
          when /o1-mini/ then 'o1_mini'
          when /o1/ then 'o1'
          when /gpt-4o-audio/ then 'gpt4o_audio'
          when /gpt-4o-realtime/ then 'gpt4o_realtime'
          when /gpt-4o-mini-audio/ then 'gpt4o_mini_audio'
          when /gpt-4o-mini-realtime/ then 'gpt4o_mini_realtime'
          when /gpt-4o-mini/ then 'gpt4o_mini'
          when /gpt-4o/ then 'gpt4o'
          when /gpt-4-turbo/ then 'gpt4_turbo'
          when /gpt-4/ then 'gpt4'
          when /gpt-3.5-turbo-instruct/ then 'gpt35_instruct'
          when /gpt-3.5/ then 'gpt35'
          when /dall-e-3/ then 'dalle3'
          when /dall-e-2/ then 'dalle2'
          when /text-embedding-3-large/ then 'embedding3_large'
          when /text-embedding-3-small/ then 'embedding3_small'
          when /text-embedding-ada/ then 'embedding2'
          when /tts-1-hd/ then 'tts1_hd'
          when /tts-1/ then 'tts1'
          when /whisper/ then 'whisper1'
          when /omni-moderation|text-moderation/ then 'moderation'
          when /babbage/ then 'babbage'
          when /davinci/ then 'davinci'
          else 'other'
          end
        end

        # Pricing information for OpenAI models (per million tokens unless otherwise specified)
        PRICES = {
          o1: { input: 15.0, cached_input: 7.5, output: 60.0 },
          o1_mini: { input: 1.10, cached_input: 0.55, output: 4.40 },
          o3_mini: { input: 1.10, cached_input: 0.55, output: 4.40 },
          gpt4o: { input: 2.50, cached_input: 1.25, output: 10.0 },
          gpt4o_audio: {
            text_input: 2.50,
            audio_input: 40.0,
            text_output: 10.0,
            audio_output: 80.0
          },
          gpt4o_realtime: {
            text_input: 5.0,
            cached_text_input: 2.50,
            audio_input: 40.0,
            cached_audio_input: 2.50,
            text_output: 20.0,
            audio_output: 80.0
          },
          gpt4o_mini: { input: 0.15, cached_input: 0.075, output: 0.60 },
          gpt4o_mini_audio: {
            text_input: 0.15,
            audio_input: 10.0,
            text_output: 0.60,
            audio_output: 20.0
          },
          gpt4o_mini_realtime: {
            text_input: 0.60,
            cached_text_input: 0.30,
            audio_input: 10.0,
            cached_audio_input: 0.30,
            text_output: 2.40,
            audio_output: 20.0
          },
          gpt4_turbo: { input: 10.0, output: 30.0 },
          gpt4: { input: 30.0, output: 60.0 },
          gpt35: { input: 0.50, output: 1.50 },
          gpt35_instruct: { input: 1.50, output: 2.0 },
          embedding3_large: { price: 0.13 },
          embedding3_small: { price: 0.02 },
          embedding2: { price: 0.10 },
          davinci: { input: 2.0, output: 2.0 },
          babbage: { input: 0.40, output: 0.40 },
          tts1: { price: 15.0 }, # per million characters
          tts1_hd: { price: 30.0 }, # per million characters
          whisper1: { price: 0.006 }, # per minute
          moderation: { price: 0.0 } # free
        }.freeze

        # Default input price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_input_price
          0.50
        end

        # Default output price when model-specific pricing is not available
        # @return [Float] the default price per million tokens
        def default_output_price
          1.50
        end

        # Converts a model ID to a human-readable format
        # @param id [String] the model identifier
        # @return [String] the humanized model name
        def humanize(id)
          id.tr('-', ' ')
            .split
            .map(&:capitalize)
            .join(' ')
        end

        # Applies special formatting rules to model names
        # @param name [String] the humanized model name
        # @return [String] the specially formatted model name
        def apply_special_formatting(name) # rubocop:disable Metrics/MethodLength
          name
            .gsub(/(\d{4}) (\d{2}) (\d{2})/, '\1\2\3')
            .gsub(/^Gpt /, 'GPT-')
            .gsub(/^O([13]) /, 'O\1-')
            .gsub(/^O3 Mini/, 'O3-Mini')
            .gsub(/^O1 Mini/, 'O1-Mini')
            .gsub(/^Chatgpt /, 'ChatGPT-')
            .gsub(/^Tts /, 'TTS-')
            .gsub(/^Dall E /, 'DALL-E-')
            .gsub('3.5 ', '3.5-')
            .gsub('4 ', '4-')
            .gsub(/4o (?=Mini|Preview|Turbo|Audio|Realtime)/, '4o-')
            .gsub(/\bHd\b/, 'HD')
            .gsub('Omni Moderation', 'Omni-Moderation')
            .gsub('Text Moderation', 'Text-Moderation')
        end
      end
    end
  end
end
