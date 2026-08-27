# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      # Model catalog for ElevenLabs. GET v1/models returns a bare array of
      # the speech synthesis models and leaves out the Scribe transcription
      # models, so those are appended from the published catalog.
      module Models
        module_function

        TRANSCRIPTION_MODELS = {
          'scribe_v2' => 'Scribe v2'
        }.freeze

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug)
          listed = Array(response.body).map do |data|
            build_model(data['model_id'], slug, name: data['name'], description: data['description'], data: data)
          end
          listed_ids = listed.map(&:id)

          listed + TRANSCRIPTION_MODELS.except(*listed_ids).map do |model_id, name|
            build_model(model_id, slug, name: name, transcription: true)
          end
        end

        def build_model(model_id, slug, name: nil, description: nil, data: {}, transcription: false)
          transcription ||= TRANSCRIPTION_MODELS.key?(model_id)

          Model.new(
            id: model_id,
            name: name || model_id,
            provider: slug,
            family: transcription ? 'scribe' : 'eleven',
            modalities: modalities_for(data, transcription),
            capabilities: capabilities_from(data, transcription),
            pricing: {},
            metadata: { description: description }.compact
          )
        end

        def modalities_for(data, transcription)
          return { input: ['audio'], output: ['text'] } if transcription
          return { input: ['audio'], output: ['audio'] } if data['can_do_voice_conversion']

          { input: ['text'], output: ['audio'] }
        end

        def capabilities_from(data, transcription)
          capabilities = []
          capabilities << 'transcription' if transcription
          capabilities << 'speech_generation' if data['can_do_text_to_speech']
          capabilities << 'fine_tuning' if data['can_be_finetuned']
          capabilities
        end
      end
    end
  end
end
