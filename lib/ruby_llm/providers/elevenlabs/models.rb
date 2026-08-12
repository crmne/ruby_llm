# frozen_string_literal: true

module RubyLLM
  module Providers
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

        def parse_list_models_response(response, slug, capabilities)
          listed = Array(response.body).map do |data|
            build_model(data['model_id'], slug, capabilities, name: data['name'], description: data['description'])
          end
          listed_ids = listed.map(&:id)

          listed + TRANSCRIPTION_MODELS.except(*listed_ids).map do |model_id, name|
            build_model(model_id, slug, capabilities, name: name)
          end
        end

        def build_model(model_id, slug, capabilities, name: nil, description: nil)
          Model.new(
            id: model_id,
            name: name || capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: {},
            metadata: { description: description }.compact
          )
        end
      end
    end
  end
end
