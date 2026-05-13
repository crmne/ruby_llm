# frozen_string_literal: true

module RubyLLM
  module Providers
    class AppleIntelligence
      # Model definitions for Apple Intelligence on-device models
      module Models
        module_function

        def models_url
          nil
        end

        def parse_list_models_response(_response, slug, _capabilities)
          [
            Model::Info.new(
              id: 'apple-intelligence',
              name: 'Apple Intelligence (on-device)',
              provider: slug,
              family: 'apple-intelligence',
              created_at: nil,
              modalities: {
                input: %w[text],
                output: %w[text]
              },
              capabilities: [],
              pricing: {},
              metadata: {
                local: true,
                description: 'Apple Foundation Model running on-device via Apple Intelligence'
              }
            )
          ]
        end
      end
    end
  end
end
