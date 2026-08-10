# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # Models metadata for xAI list models. The list endpoint omits the
      # model-less TTS and STT services, so those are appended under the
      # grok-tts and grok-stt names from xAI's model catalog.
      module Models
        module_function

        AUDIO_MODELS = {
          'grok-tts' => {
            name: 'Grok TTS',
            modalities: { input: ['text'], output: ['audio'] },
            capabilities: []
          },
          'grok-stt' => {
            name: 'Grok STT',
            modalities: { input: ['audio'], output: ['text'] },
            capabilities: ['transcription']
          }
        }.freeze

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model.new(
              id: model_id,
              name: format_display_name(model_id),
              provider: slug,
              family: 'grok',
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: modalities_for(model_id),
              capabilities: capabilities_for(model_id),
              pricing: {},
              metadata: {
                object: model_data['object'],
                owned_by: model_data['owned_by']
              }.compact
            )
          end + audio_models(slug)
        end

        def audio_models(slug)
          AUDIO_MODELS.map do |model_id, info|
            Model.new(
              id: model_id,
              name: info[:name],
              provider: slug,
              family: 'grok',
              modalities: info[:modalities],
              capabilities: info[:capabilities],
              pricing: {},
              metadata: {}
            )
          end
        end

        def modalities_for(model_id)
          if image_model?(model_id)
            { input: %w[text image], output: ['image'] }
          elsif video_model?(model_id)
            { input: %w[text image video], output: ['video'] }
          else
            { input: ['text'], output: ['text'] }
          end
        end

        def capabilities_for(model_id)
          return ['vision'] if image_model?(model_id) || video_model?(model_id)

          ['streaming']
        end

        def format_display_name(model_id)
          model_id.tr('-', ' ').split.map(&:capitalize).join(' ')
        end

        def image_model?(model_id)
          model_id.match?(/\Agrok-(?:2-)?imagine-image/) || model_id == 'grok-2-image-1212'
        end

        def video_model?(model_id)
          model_id.match?(/\Agrok-(?:2-)?imagine-video/)
        end
      end
    end
  end
end
