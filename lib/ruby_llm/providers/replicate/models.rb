# frozen_string_literal: true

module RubyLLM
  module Providers
    class Replicate
      # Models methods of the Replicate API integration
      module Models
        def list_models(**)
          response = @connection.get models_url
          parse_list_models_response response
        end

        def models_url
          '/v1/collections/text-to-image'
        end

        def parse_list_models_response(response)
          Array(response.body['models']).map do |model_data|
            Model::Info.new(
              id: model_data.dig('latest_version', 'id'),
              name: "#{model_data['owner']}/#{model_data['name']}",
              provider: 'replicate',
              created_at: model_data['created_at'],
              modalities: { input: ['text'], output: ['image'] },
              capabilities: ['image_generation'],
              metadata: capabilities.metadata_from(model_data)
            )
          end
        end
      end
    end
  end
end
