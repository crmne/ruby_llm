# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Deepgram
      # Model catalog for Deepgram. GET v1/models splits the catalog into
      # stt and tts groups, and names each entry twice: +name+ is the short
      # name, such as the voice 'zeus', while +canonical_name+ is the id the
      # listen and speak endpoints accept.
      module Models
        module_function

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug, capabilities)
          body = response.body || {}

          %w[stt tts].flat_map do |group|
            Array(body[group]).group_by { |data| data['canonical_name'] || data['name'] }
                              .map { |_, rows| build_model(merge_language_rows(rows), slug, capabilities) }
          end
        end

        # Deepgram lists a model once per language it was trained on, so
        # nova-3-general arrives 146 times with a different language and
        # version each time. One model answers to that id, so the rows
        # collapse into it, carrying every language between them. Fields
        # the rows disagree on describe a single language rather than the
        # model, and are left out.
        def merge_language_rows(rows)
          merged = rows.first.merge('languages' => rows.flat_map { |row| Array(row['languages']) }.uniq.sort)
          %w[version architecture].each do |key|
            merged.delete(key) unless rows.map { |row| row[key] }.uniq.one?
          end
          merged
        end

        def build_model(data, slug, capabilities)
          model_id = data['canonical_name'] || data['name']

          Model.new(
            id: model_id,
            name: capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: {},
            metadata: build_metadata(data)
          )
        end

        def build_metadata(data)
          metadata = {
            architecture: data['architecture'],
            languages: data['languages'],
            version: data['version']
          }
          metadata[:voice] = data['name'] if data['name'] && data['name'] != data['canonical_name']
          metadata.merge!(data['metadata'].transform_keys(&:to_sym)) if data['metadata'].is_a?(Hash)
          metadata.compact
        end
      end
    end
  end
end
