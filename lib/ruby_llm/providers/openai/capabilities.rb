# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Provider-level capability checks and narrow registry fallbacks.
      module Capabilities
        module_function

        MODEL_PATTERNS = {
          gpt41: /^gpt-4\.1(?!-(?:mini|nano))/,
          gpt41_mini: /^gpt-4\.1-mini/,
          gpt41_nano: /^gpt-4\.1-nano/,
          gpt4: /^gpt-4(?:-\d{6})?$/,
          gpt4_turbo: /^gpt-4(?:\.5)?-(?:\d{6}-)?(preview|turbo)/,
          gpt35_turbo: /^gpt-3\.5-turbo/,
          gpt4o: /^gpt-4o(?!-(?:mini|audio|realtime|transcribe|tts|search))/,
          gpt4o_audio: /^gpt-4o-(?:audio)/,
          gpt4o_mini: /^gpt-4o-mini(?!-(?:audio|realtime|transcribe|tts|search))/,
          gpt4o_mini_audio: /^gpt-4o-mini-audio/,
          gpt4o_mini_realtime: /^gpt-4o-mini-realtime/,
          gpt4o_mini_transcribe: /^gpt-4o-mini-transcribe/,
          gpt4o_mini_tts: /^gpt-4o-mini-tts/,
          gpt4o_realtime: /^gpt-4o-realtime/,
          gpt4o_search: /^gpt-4o-search/,
          gpt4o_transcribe: /^gpt-4o-transcribe/,
          gpt5: /^gpt-5(?!.*(?:mini|nano))/,
          gpt5_mini: /^gpt-5.*mini/,
          gpt5_nano: /^gpt-5.*nano/,
          o1: /^o1(?!-(?:mini|pro))/,
          o1_mini: /^o1-mini/,
          o1_pro: /^o1-pro/,
          o3_mini: /^o3-mini/,
          babbage: /^babbage/,
          davinci: /^davinci/,
          embedding3_large: /^text-embedding-3-large/,
          embedding3_small: /^text-embedding-3-small/,
          embedding_ada: /^text-embedding-ada/,
          tts1: /^tts-1(?!-hd)/,
          tts1_hd: /^tts-1-hd/,
          whisper: /^whisper/,
          moderation: /^(?:omni|text)-moderation/
        }.freeze

        PRICES = {
          gpt5: { input: 1.25, output: 10.0, cached_input: 0.125 },
          gpt5_mini: { input: 0.25, output: 2.0, cached_input: 0.025 },
          gpt5_nano: { input: 0.05, output: 0.4, cached_input: 0.005 },
          gpt41: { input: 2.0, output: 8.0, cached_input: 0.5 },
          gpt41_mini: { input: 0.4, output: 1.6, cached_input: 0.1 },
          gpt41_nano: { input: 0.1, output: 0.4 },
          gpt4: { input: 10.0, output: 30.0 },
          gpt4_turbo: { input: 10.0, output: 30.0 },
          gpt35_turbo: { input: 0.5, output: 1.5 },
          gpt4o: { input: 2.5, output: 10.0 },
          gpt4o_audio: { input: 2.5, output: 10.0 },
          gpt4o_mini: { input: 0.15, output: 0.6 },
          gpt4o_mini_audio: { input: 0.15, output: 0.6 },
          gpt4o_mini_realtime: { input: 0.6, output: 2.4 },
          gpt4o_mini_transcribe: { input: 1.25, output: 5.0 },
          gpt4o_mini_tts: { input: 0.6, output: 12.0 },
          gpt4o_realtime: { input: 5.0, output: 20.0 },
          gpt4o_search: { input: 2.5, output: 10.0 },
          gpt4o_transcribe: { input: 2.5, output: 10.0 },
          o1: { input: 15.0, output: 60.0 },
          o1_mini: { input: 1.1, output: 4.4 },
          o1_pro: { input: 150.0, output: 600.0 },
          o3_mini: { input: 1.1, output: 4.4 },
          babbage: { input: 0.4, output: 0.4 },
          davinci: { input: 2.0, output: 2.0 },
          embedding3_large: { price: 0.13 },
          embedding3_small: { price: 0.02 },
          embedding_ada: { price: 0.10 },
          tts1: { price: 15.0 },
          tts1_hd: { price: 30.0 },
          whisper: { price: 0.006 },
          moderation: { price: 0.0 }
        }.freeze

        def supports_tool_choice?(_model_id)
          true
        end

        def supports_tool_parallel_control?(_model_id)
          true
        end

        def context_window_for(model_id)
          case model_family(model_id)
          when 'gpt41', 'gpt41_mini', 'gpt41_nano' then 1_047_576
          when 'gpt5', 'gpt5_mini', 'gpt5_nano', 'gpt4_turbo', 'gpt4o', 'gpt4o_audio', 'gpt4o_mini',
               'gpt4o_mini_audio', 'gpt4o_mini_realtime', 'gpt4o_realtime', 'gpt4o_search',
               'gpt4o_transcribe', 'o1_mini' then 128_000
          when 'gpt4' then 8_192
          when 'gpt4o_mini_transcribe' then 16_000
          when 'o1', 'o1_pro', 'o3_mini' then 200_000
          when 'gpt35_turbo' then 16_385
          when 'gpt4o_mini_tts', 'tts1', 'tts1_hd', 'whisper', 'moderation',
               'embedding3_large', 'embedding3_small', 'embedding_ada' then nil
          else 4_096
          end
        end

        def max_tokens_for(model_id)
          case model_family(model_id)
          when 'gpt5', 'gpt5_mini', 'gpt5_nano' then 400_000
          when 'gpt41', 'gpt41_mini', 'gpt41_nano' then 32_768
          when 'gpt4' then 8_192
          when 'gpt35_turbo' then 4_096
          when 'gpt4o_mini_transcribe' then 2_000
          when 'o1', 'o1_pro', 'o3_mini' then 100_000
          when 'o1_mini' then 65_536
          when 'gpt4o_mini_tts', 'tts1', 'tts1_hd', 'whisper', 'moderation',
               'embedding3_large', 'embedding3_small', 'embedding_ada' then nil
          else 16_384
          end
        end

        def critical_capabilities_for(model_id)
          capabilities = []
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_structured_output?(model_id)
          capabilities << 'vision' if supports_vision?(model_id)
          capabilities << 'reasoning' if model_id.match?(/o\d|gpt-5|codex/)
          capabilities
        end

        def pricing_for(model_id)
          standard_pricing = {
            input_per_million: input_price_for(model_id),
            output_per_million: output_price_for(model_id)
          }

          cached_price = cached_input_price_for(model_id)
          standard_pricing[:cached_input_per_million] = cached_price if cached_price

          { text_tokens: { standard: standard_pricing } }
        end

        def model_family(model_id)
          MODEL_PATTERNS.each do |family, pattern|
            return family.to_s if model_id.match?(pattern)
          end

          'other'
        end

        def supports_vision?(model_id)
          case model_family(model_id)
          when 'gpt5', 'gpt5_mini', 'gpt5_nano', 'gpt41', 'gpt41_mini', 'gpt41_nano', 'gpt4',
               'gpt4_turbo', 'gpt4o', 'gpt4o_mini', 'o1', 'o1_pro', 'moderation', 'gpt4o_search'
            true
          else
            false
          end
        end

        def supports_functions?(model_id)
          case model_family(model_id)
          when 'gpt5', 'gpt5_mini', 'gpt5_nano', 'gpt41', 'gpt41_mini', 'gpt41_nano', 'gpt4',
               'gpt4_turbo', 'gpt4o', 'gpt4o_mini', 'o1', 'o1_pro', 'o3_mini'
            true
          else
            false
          end
        end

        def supports_structured_output?(model_id)
          case model_family(model_id)
          when 'gpt5', 'gpt5_mini', 'gpt5_nano', 'gpt41', 'gpt41_mini', 'gpt41_nano', 'gpt4o',
               'gpt4o_mini', 'o1', 'o1_pro', 'o3_mini'
            true
          else
            false
          end
        end

        def input_price_for(model_id)
          price_for(model_id, :input, 0.50)
        end

        def output_price_for(model_id)
          price_for(model_id, :output, 1.50)
        end

        def cached_input_price_for(model_id)
          family = model_family(model_id).to_sym
          PRICES.fetch(family, {})[:cached_input]
        end

        def price_for(model_id, key, fallback)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { key => fallback })
          prices[key] || prices[:price] || fallback
        end

        module_function :context_window_for, :max_tokens_for, :critical_capabilities_for, :pricing_for,
                        :model_family, :supports_vision?, :supports_functions?, :supports_structured_output?,
                        :input_price_for, :output_price_for, :cached_input_price_for, :price_for
      end
    end
  end
end
