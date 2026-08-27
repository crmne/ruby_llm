# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Model information for the Cohere API
      module Models
        module_function

        FEATURE_CAPABILITIES = {
          'tools' => 'function_calling',
          'tool_choice' => 'tool_choice',
          'json_schema' => 'structured_output',
          'json_mode' => 'json_mode',
          'citations' => 'citations'
        }.freeze

        # The model catalog is the one endpoint Cohere still serves from v1.
        def models_url
          'v1/models?page_size=1000'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['models']).reject { |model| model['is_deprecated'] }.map do |model_data|
            model_id = model_data['name']
            endpoints = Array(model_data['endpoints'])

            Model.new(
              id: model_id,
              name: model_id,
              provider: slug,
              context_window: model_data['context_length']&.to_i,
              modalities: modalities_from(endpoints),
              capabilities: capabilities_from(endpoints, model_data['features']),
              metadata: {
                endpoints: endpoints,
                default_endpoints: Array(model_data['default_endpoints']),
                features: Array(model_data['features']),
                finetuned: model_data['finetuned'],
                tokenizer_url: model_data['tokenizer_url']
              }.compact
            )
          end
        end

        def modalities_from(endpoints)
          return { input: ['audio'], output: ['text'] } if transcription_endpoint?(endpoints)

          if embedding_endpoint?(endpoints)
            input = []
            input << 'text' if endpoints.include?('embed')
            input << 'image' if endpoints.any? { |endpoint| endpoint.start_with?('embed_image') }
            return { input: input.empty? ? ['text'] : input, output: ['embeddings'] }
          end

          return { input: ['text'], output: ['rerank'] } if rerank_endpoint?(endpoints)

          { input: ['text'], output: ['text'] }
        end

        def capabilities_from(endpoints, features)
          return ['transcription'] if transcription_endpoint?(endpoints)
          return [] if embedding_endpoint?(endpoints) || rerank_endpoint?(endpoints)

          features = Array(features)
          capabilities = []
          capabilities << 'streaming' if endpoints.intersect?(%w[chat generate])
          reported = FEATURE_CAPABILITIES.filter_map do |feature, capability|
            capability if features.include?(feature)
          end
          capabilities.concat(reported)
          capabilities
        end

        def embedding_endpoint?(endpoints)
          endpoints.any? { |endpoint| endpoint.start_with?('embed') }
        end

        def rerank_endpoint?(endpoints)
          endpoints.any? { |endpoint| endpoint.start_with?('rerank') }
        end

        def transcription_endpoint?(endpoints)
          endpoints.any? { |endpoint| endpoint.start_with?('transcri') }
        end
      end
    end
  end
end
