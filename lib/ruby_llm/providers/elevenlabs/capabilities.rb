# frozen_string_literal: true

module RubyLLM
  module Providers
    class ElevenLabs
      # Determines capabilities for ElevenLabs models. The catalog is audio
      # only: Scribe models transcribe speech, the speech-to-speech models
      # convert one voice into another, and everything else speaks text.
      module Capabilities
        module_function

        def modalities_for(model_id)
          if transcription?(model_id)
            { input: ['audio'], output: ['text'] }
          elsif voice_conversion?(model_id)
            { input: ['audio'], output: ['audio'] }
          else
            { input: ['text'], output: ['audio'] }
          end
        end

        def capabilities_for(model_id)
          transcription?(model_id) ? ['transcription'] : []
        end

        def model_family(model_id)
          return 'scribe' if transcription?(model_id)
          return 'music' if model_id.start_with?('music')

          'eleven'
        end

        def format_display_name(model_id)
          model_id.tr('_', ' ').split.map(&:capitalize).join(' ')
        end

        def transcription?(model_id)
          model_id.start_with?('scribe')
        end

        def voice_conversion?(model_id)
          model_id.include?('_sts_')
        end
      end
    end
  end
end
