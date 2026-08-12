# frozen_string_literal: true

module RubyLLM
  module Providers
    class Deepgram
      # Determines capabilities for Deepgram models. The catalog is audio
      # only, and the id says which way the audio flows: Nova, Whisper, and
      # the Flux general models listen, while Aura and the Flux voices
      # speak. Flux runs over WebSockets on v2, which RubyLLM does not
      # speak, so those models claim no capability from the registry.
      module Capabilities
        module_function

        TRANSCRIPTION_FAMILIES = %w[nova whisper enhanced base flux-general].freeze

        def modalities_for(model_id)
          if transcription?(model_id)
            { input: ['audio'], output: ['text'] }
          else
            { input: ['text'], output: ['audio'] }
          end
        end

        def capabilities_for(model_id)
          return [] if websocket_only?(model_id)

          transcription?(model_id) ? ['transcription'] : []
        end

        def model_family(model_id)
          model_id[/\A(flux|nova|whisper|enhanced|base|aura)/, 1] || 'deepgram'
        end

        def format_display_name(model_id)
          model_id.split('-').map { |part| part.match?(/\A[a-z]{2}\z/) ? part.upcase : part.capitalize }.join(' ')
        end

        def transcription?(model_id)
          model_id.start_with?(*TRANSCRIPTION_FAMILIES)
        end

        # Flux is Deepgram's WebSocket generation: v2/listen transcribes and
        # v2/speak speaks. RubyLLM talks to the REST endpoints only.
        def websocket_only?(model_id)
          model_id.start_with?('flux-')
        end
      end
    end
  end
end
