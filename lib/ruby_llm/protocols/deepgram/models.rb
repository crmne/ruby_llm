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
            Array(body[group]).map { |data| build_model(data, slug, capabilities) }
          end
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
