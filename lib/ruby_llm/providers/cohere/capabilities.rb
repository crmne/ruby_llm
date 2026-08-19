# frozen_string_literal: true

module RubyLLM
  module Providers
    class Cohere
      # Determines capabilities for Cohere models
      module Capabilities
        extend CapabilityTable

        CONTEXT_WINDOWS = {
          'command-a-plus-05-2026' => 128_000,
          'command-a-03-2025' => 256_000,
          'command-a-reasoning-08-2025' => 256_000,
          'command-a-vision-07-2025' => 128_000,
          'command-a-translate-08-2025' => 8_000,
          'command-r7b-12-2024' => 128_000,
          'command-r-08-2024' => 128_000,
          'command-r-plus-08-2024' => 128_000,
          'c4ai-aya-expanse-32b' => 128_000,
          'c4ai-aya-vision-32b' => 16_000,
          'embed-v4.0' => 128_000,
          'rerank-v4.0-pro' => 32_000,
          'rerank-v4.0-fast' => 32_000
        }.freeze

        MAX_OUTPUT_TOKENS = {
          'command-a-plus-05-2026' => 64_000,
          'command-a-03-2025' => 8_000,
          'command-a-reasoning-08-2025' => 32_000,
          'command-a-vision-07-2025' => 8_000,
          'command-a-translate-08-2025' => 8_000
        }.freeze

        RELEASE_DATES = {
          'command-a-plus-05-2026' => '2026-05-20',
          'command-a-translate-08-2025' => '2025-08-28',
          'command-a-reasoning-08-2025' => '2025-08-21',
          'command-a-vision-07-2025' => '2025-07-31',
          'command-a-03-2025' => '2025-03-13',
          'command-r7b-12-2024' => '2024-12-02',
          'command-r-08-2024' => '2024-08-30',
          'command-r-plus-08-2024' => '2024-08-30',
          'c4ai-aya-expanse-32b' => '2024-10-24',
          'c4ai-aya-vision-32b' => '2025-03-04',
          'cohere-transcribe-03-2026' => '2026-03-01'
        }.freeze

        PRICES = {
          'command-a-plus-05-2026' => { input: 2.5, output: 10.0 },
          'command-a-03-2025' => { input: 2.5, output: 10.0 },
          'command-a-reasoning-08-2025' => { input: 2.5, output: 10.0 },
          'command-a-vision-07-2025' => { input: 2.5, output: 10.0 },
          'command-a-translate-08-2025' => { input: 2.5, output: 10.0 },
          'command-r-plus-08-2024' => { input: 2.5, output: 10.0 },
          'command-r-08-2024' => { input: 0.15, output: 0.6 },
          'command-r7b-12-2024' => { input: 0.0375, output: 0.15 },
          'c4ai-aya-expanse-32b' => { input: 0.5, output: 1.5 },
          'c4ai-aya-vision-32b' => { input: 0.5, output: 1.5 }
        }.freeze

        # Cohere is retiring tool_choice: the Command R models and
        # command-a-03-2025 take it, while everything since answers
        # "tool_choice is not supported for this model". New models are
        # assumed not to take it until one is confirmed to.
        TOOL_CHOICE_MODELS = %w[
          command-a-03-2025
          command-r-08-2024
          command-r-plus-08-2024
          command-r7b-12-2024
        ].freeze

        VISION_MODELS = %w[command-a-plus-05-2026 command-a-vision-07-2025 c4ai-aya-vision-32b embed-v4.0].freeze

        # Tool use, structured output, and citations are Command features; the
        # Aya research models reach the Chat endpoint without them, and so
        # does the vision model, which answers "tool use is not supported by
        # the provided model".
        TOOL_MODELS = lambda { |model_id|
          chat?(model_id) && !model_id.start_with?('c4ai-aya', 'tiny-aya') &&
            !%w[command-a-translate-08-2025 command-a-vision-07-2025].include?(model_id)
        }

        CAPABILITIES = {
          'streaming' => true,
          'function_calling' => TOOL_MODELS,
          'structured_output' => TOOL_MODELS,
          'citations' => TOOL_MODELS,
          'tool_choice' => TOOL_CHOICE_MODELS,
          'vision' => lambda { |model_id|
            VISION_MODELS.include?(model_id) || model_id.match?(/embed-(english|multilingual)/)
          },
          'reasoning' => lambda { |model_id|
            %w[command-a-plus-05-2026 command-a-reasoning-08-2025].include?(model_id) ||
              model_id.start_with?('north-')
          }
        }.freeze

        module_function

        def embedding?(model_id)
          model_id.start_with?('embed')
        end

        def rerank?(model_id)
          model_id.start_with?('rerank')
        end

        def transcription?(model_id)
          model_id.include?('transcribe')
        end

        def chat?(model_id)
          !embedding?(model_id) && !rerank?(model_id) && !transcription?(model_id)
        end

        def context_window_for(model_id)
          CONTEXT_WINDOWS[model_id] || (chat?(model_id) ? 128_000 : 4_096)
        end

        def max_tokens_for(model_id)
          MAX_OUTPUT_TOKENS[model_id] || (chat?(model_id) ? 4_000 : nil)
        end

        def release_date_for(model_id)
          RELEASE_DATES[model_id]
        end

        def modalities_for(model_id)
          return { input: text_and_image(model_id), output: ['embeddings'] } if embedding?(model_id)
          return { input: ['text'], output: ['rerank'] } if rerank?(model_id)
          return { input: ['audio'], output: ['text'] } if transcription?(model_id)

          { input: text_and_image(model_id), output: ['text'] }
        end

        def text_and_image(model_id)
          supports?(model_id, 'vision') ? %w[text image] : ['text']
        end

        def capabilities_for(model_id, endpoints = [])
          return ['transcription'] if transcription?(model_id) || endpoints.include?('transcribe')
          return [] if embedding?(model_id) || rerank?(model_id) || endpoints.intersect?(%w[embed rerank])

          supported_capabilities(model_id)
        end

        def pricing_for(model_id)
          price = PRICES[model_id]
          return {} unless price

          { text_tokens: { standard: { input_per_million: price[:input], output_per_million: price[:output] } } }
        end

        def format_display_name(model_id)
          model_id.split('-').map do |part|
            part.match?(/\A(v?\d|\d)/) ? part : part.capitalize
          end.join(' ')
        end

        def model_family(model_id)
          case model_id
          when /\Acommand-a-plus/ then 'command-a-plus'
          when /\Acommand-a/ then 'command-a'
          when /\Acommand-r-plus/ then 'command-r-plus'
          when /\Acommand-r-/ then 'command-r'
          when /\Aembed/ then 'embed'
          when /\Arerank/ then 'rerank'
          when /transcribe/ then 'transcribe'
          when /aya/ then 'aya'
          else 'command'
          end
        end
      end
    end
  end
end
