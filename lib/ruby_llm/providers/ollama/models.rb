# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Models methods for the Ollama API integration
      module Models
        SHOW_URL = '../api/show'
        CAPABILITY_MAP = {
          'tools' => 'function_calling',
          'vision' => 'vision',
          'thinking' => 'reasoning'
        }.freeze

        def models_url
          'models'
        end

        def model_capabilities
          %w[streaming structured_output]
        end

        def list_models
          response = @connection.get models_url
          parse_list_models_response(response, @provider.slug, @provider.capabilities, details: show_models(response))
        end

        def parse_list_models_response(response, slug, _capabilities, details: {})
          Array(response.body['data']).map do |model|
            reported = Array(details[model['id']])
            Model.new(
              id: model['id'],
              name: model['id'],
              provider: slug,
              family: 'ollama',
              created_at: model['created'] ? Time.at(model['created']) : nil,
              modalities: build_modalities(reported),
              capabilities: build_capabilities(reported),
              pricing: {},
              metadata: {
                owned_by: model['owned_by']
              }
            )
          end
        end

        private

        def show_models(response)
          Array(response.body['data']).filter_map { |model| model['id'] }.to_h { |id| [id, show_model(id)] }
        end

        def show_model(id)
          Array(@connection.post(SHOW_URL, { model: id }).body['capabilities'])
        rescue Error, Faraday::Error => e
          RubyLLM.logger.debug "Ollama did not report capabilities for #{id} (#{e.message})."
          []
        end

        def build_capabilities(reported)
          return [] if reported.include?('embedding')

          derived = CAPABILITY_MAP.filter_map { |native, capability| capability if reported.include?(native) }
          model_capabilities + derived
        end

        def build_modalities(reported)
          return { input: %w[text], output: %w[embeddings] } if reported.include?('embedding')

          input = %w[text]
          input << 'image' if reported.include?('vision')
          { input: input, output: %w[text] }
        end
      end
    end
  end
end
