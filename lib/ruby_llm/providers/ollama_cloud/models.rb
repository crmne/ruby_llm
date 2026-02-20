# frozen_string_literal: true

module RubyLLM
  module Providers
    class OllamaCloud
      # Models methods for the Ollama Cloud API
      module Models
        def models_url
          'api/tags'
        end

        def parse_list_models_response(response, slug, _capabilities)
          data = response.body['models'] || []
          data.map do |model|
            Model::Info.new(
              id: model['name'],
              name: model['name'],
              provider: slug,
              family: model.dig('details', 'family') || 'ollama',
              created_at: begin
                Time.at(model['modified_at'])
              rescue StandardError
                nil
              end,
              context_window: model.dig('details', 'context_length'),
              modalities: {
                input: %w[text],
                output: %w[text]
              },
              capabilities: infer_capabilities(model),
              metadata: {
                size: model['size'],
                digest: model['digest'],
                format: model.dig('details', 'format'),
                quantization: model.dig('details', 'quantization_level')
              }
            )
          end
        end

        private

        def infer_capabilities(model)
          caps = %w[streaming]

          # Cloud models often support more features
          name = model['name'].to_s.downcase

          caps << 'vision' if name.include?('vision') || name.include?('vl')

          caps << 'function_calling' if name.include?('tools') || name.include?('function')

          caps
        end
      end
    end
  end
end
