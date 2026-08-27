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

            models.concat(parse_list_models_response(response, @provider.slug))
            page_token = response.body['nextPageToken']
            break unless page_token
          end

          models
        end

        private

        def models_url
          'models'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['models']).map do |model_data|
            model_id = model_data['name'].gsub('models/', '')
            methods = Array(model_data['supportedGenerationMethods'])

            Model.new(
              id: model_id,
              name: model_data['displayName'] || model_id,
              provider: slug,
              created_at: nil,
              context_window: model_data['inputTokenLimit'],
              max_output_tokens: model_data['outputTokenLimit'],
              modalities: modalities_from(methods),
              capabilities: capabilities_from(methods),
              metadata: {
                version: model_data['version'],
                description: model_data['description'],
                supported_generation_methods: methods
              }
            )
          end
        end

        def modalities_from(methods)
          return unless methods.include?('embedContent')

          { input: ['text'], output: ['embeddings'] }
        end

        def capabilities_from(methods)
          capabilities = []
          capabilities << 'batch' if methods.intersect?(%w[batchGenerateContent asyncBatchEmbedContent])
          capabilities << 'caching' if methods.include?('createCachedContent')
          capabilities.push('streaming', 'realtime') if methods.include?('bidiGenerateContent')
          capabilities
        end
      end
    end
  end
end
