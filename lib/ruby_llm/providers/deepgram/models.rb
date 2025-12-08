# frozen_string_literal: true

module RubyLLM
  module Providers
    class Deepgram
      # Models methods for the Deepgram API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['stt']).map do |model_data|
            model_id = model_data['canonical_name'] || model_data['name']

            Model::Info.new(
              id: model_id,
              name: capabilities.format_display_name(model_id),
              provider: slug,
              family: model_data['architecture'] || capabilities.model_family(model_id),
              created_at: nil,
              context_window: nil,
              max_output_tokens: nil,
              modalities: capabilities.modalities_for(model_id),
              capabilities: extract_capabilities(model_data),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                uuid: model_data['uuid'],
                version: model_data['version'],
                languages: model_data['languages'],
                batch: model_data['batch'],
                streaming: model_data['streaming']
              }
            )
          end
        end

        def extract_capabilities(model_data)
          caps = ['transcription']
          caps << 'streaming' if model_data['streaming']
          caps << 'batch' if model_data['batch']
          caps
        end
      end
    end
  end
end
