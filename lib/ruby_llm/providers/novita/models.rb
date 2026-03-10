# frozen_string_literal: true

module RubyLLM
  module Providers
    class Novita
      # Models methods of the Novita API integration
      module Models
        module_function

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body['data']).map do |model_data|
            model_id = model_data['id']

            Model::Info.new(
              id: model_id,
              name: model_id,
              provider: slug,
              family: 'openai',
              created_at: model_data['created'] ? Time.at(model_data['created']) : nil,
              context_window: 128_000,
              max_output_tokens: 4096,
              modalities: {
                input: ['text', 'image'],
                output: ['text']
              },
              capabilities: ['streaming', 'function_calling', 'structured_output'],
              pricing: {
                text_tokens: { standard: {} }
              },
              metadata: {
                object: model_data['object'],
                owned_by: model_data['owned_by']
              }
            )
          end
        end
      end
    end
  end
end
