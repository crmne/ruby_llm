# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Models methods for the Gemini API integration
      module Models
        def list_models
          models = []
          page_token = nil

          loop do
            response = @connection.get(models_url) do |req|
              req.params = { pageSize: 1000 }
              req.params[:pageToken] = page_token if page_token
            end

            models.concat(parse_list_models_response(response, @provider.slug, @provider.capabilities))
            page_token = response.body['nextPageToken']
            break unless page_token
          end

          models
        end

        private

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['models']).map do |model_data|
            model_id = model_data['name'].gsub('models/', '')

            Model.new(
              id: model_id,
              name: model_data['displayName'] || model_id,
              provider: slug,
              created_at: nil,
              context_window: model_data['inputTokenLimit'] || capabilities.context_window_for(model_id),
              max_output_tokens: model_data['outputTokenLimit'] || capabilities.max_tokens_for(model_id),
              capabilities: capabilities.critical_capabilities_for(model_id),
              pricing: capabilities.pricing_for(model_id),
              metadata: {
                version: model_data['version'],
                description: model_data['description'],
                supported_generation_methods: model_data['supportedGenerationMethods']
              }
            )
          end
        end
      end
    end
  end
end
