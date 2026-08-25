# frozen_string_literal: true

require 'time'

module RubyLLM
  module Providers
    class Mistral
      # Model information for Mistral
      module Models
        # Mistral's capability flags, named as ModelSchema::CAPABILITIES names.
        # Flags the listing leaves out fall back to the Capabilities table.
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

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']
            flags = model_data['capabilities'] || {}

            Model.new(
              id: model_id,
              name: capabilities&.format_display_name(model_id) || model_id,
              provider: slug,
              family: capabilities&.model_family(model_id),
              created_at: release_date_from(capabilities, model_id),
              context_window: model_data['max_context_length'] || capabilities&.context_window_for(model_id),
              max_output_tokens: capabilities&.max_tokens_for(model_id),
              modalities: modalities_from(flags, capabilities&.modalities_for(model_id)),
              capabilities: capabilities_from(flags, capabilities&.capabilities_for(model_id)),
              pricing: capabilities&.pricing_for(model_id) || {},
              metadata: metadata_from(model_data)
            )
          end
        end

        def release_date_from(capabilities, model_id)
          release_date = capabilities&.release_date_for(model_id)
          Time.parse(release_date) if release_date
        end

        def capabilities_from(flags, fallback)
          reported = CAPABILITY_FLAGS.select { |flag, _| flags.key?(flag) }
          enabled, disabled = reported.partition { |flag, _| flags[flag] }

          (Array(fallback) - disabled.map(&:last)) | enabled.map(&:last)
        end

        def modalities_from(flags, fallback)
          modalities = fallback || { input: ['text'], output: ['text'] }
          return modalities unless flags['vision'] || flags['ocr']

          modalities.merge(input: modalities[:input] | ['image'])
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
