# frozen_string_literal: true

module RubyLLM
  module Providers
    class Deepgram
      # Determines capabilities and pricing for Deepgram models
      module Capabilities
        module_function

        # Per-minute pricing (stored in input_per_million like Whisper)
        PRICES = {
          nova3: 0.0043,
          nova3_medical: 0.0075,
          nova2: 0.0043,
          nova2_medical: 0.0075,
          nova: 0.0043,
          whisper: 0.0048,
          enhanced: 0.0145,
          base: 0.0125
        }.freeze

        def model_family(model_id)
          case model_id
          when /^nova-3-medical/ then 'nova3_medical'
          when /^nova-3/ then 'nova3'
          when /^nova-2-medical/ then 'nova2_medical'
          when /^nova-2/ then 'nova2'
          when /^nova/ then 'nova'
          when /^whisper/ then 'whisper'
          when /^enhanced/ then 'enhanced'
          else 'base'
          end
        end

        def format_display_name(model_id)
          model_id.split('-').map(&:capitalize).join(' ')
        end

        def model_type(_model_id)
          'audio'
        end

        def modalities_for(_model_id)
          { input: ['audio'], output: ['text'] }
        end

        def capabilities_for(_model_id)
          ['transcription']
        end

        def pricing_for(model_id)
          family = model_family(model_id).to_sym
          price = PRICES.fetch(family, PRICES[:base])

          {
            text_tokens: {
              standard: { input_per_million: price }
            }
          }
        end
      end
    end
  end
end
