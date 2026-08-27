# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Models methods of the OpenAI API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model.new(
              id: model_id,
              name: model_id,
              provider: slug,
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              metadata: model_metadata(model_data)
            )
          end
        end

        def model_metadata(model_data)
          metadata = {
            object: model_data['object'],
            owned_by: model_data['owned_by']
          }
          metadata[:shutdown_date] = model_data['shutdown_date'] if model_data['shutdown_date']
          metadata
        end
      end
    end
  end
end
