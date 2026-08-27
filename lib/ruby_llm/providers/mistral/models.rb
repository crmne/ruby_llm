# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Model information for Mistral
      module Models
        # Mistral's capability flags, named as ModelSchema::CAPABILITIES names.
        CAPABILITY_FLAGS = {
          'function_calling' => 'function_calling',
          'reasoning' => 'reasoning',
          'fine_tuning' => 'fine_tuning',
          'vision' => 'vision',
          'ocr' => 'vision',
          'moderation' => 'moderation',
          'audio_transcription' => 'transcription',
          'audio_transcription_realtime' => 'realtime',
          'audio_speech' => 'speech_generation'
        }.freeze

        module_function

        def models_url
          'models'
        end

        def models_dev_alias(model_id, models_dev_by_key, provider_model = nil)
          source = Array(provider_model&.metadata&.[](:aliases)).filter_map do |alias_id|
            models_dev_by_key["mistral:#{alias_id}"]
          end.first
          Model.new(source.to_h.merge(id: model_id)) if source
        end

        def parse_list_models_response(response, slug)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']
            flags = model_data['capabilities'] || {}

            Model.new(
              id: model_id,
              name: model_id,
              provider: slug,
              context_window: model_data['max_context_length'],
              modalities: modalities_from(flags, model_data),
              capabilities: capabilities_from(flags),
              metadata: metadata_from(model_data)
            )
          end
        end

        def capabilities_from(flags)
          CAPABILITY_FLAGS.filter_map { |flag, capability| capability if flags[flag] }
        end

        def modalities_from(flags, model_data)
          return { input: ['text'], output: ['embeddings'] } if embedding_model?(model_data)
          return { input: ['audio'], output: ['text'] } if flags['audio_transcription']

          input = ['text']
          input << 'image' if flags['vision'] || flags['ocr']
          output = ['text']
          output << 'audio' if flags['audio_speech']
          { input: input, output: output }
        end

        def embedding_model?(model_data)
          values = [model_data['id'], model_data['description'], *Array(model_data['aliases'])]
          values.any? { |value| value.to_s.match?(/(?:\A|[-_ ])embed(?:ding)?(?:\z|[-_ ])/i) }
        end

        def metadata_from(model_data)
          {
            object: model_data['object'],
            owned_by: model_data['owned_by'],
            description: model_data['description'],
            aliases: model_data['aliases'],
            deprecation: model_data['deprecation'],
            deprecation_replacement_model: model_data['deprecation_replacement_model']
          }.reject { |_, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
        end
      end
    end
  end
end
