# frozen_string_literal: true

module RubyLLM
  module Protocols
    class SystemOne
      module Models # :nodoc:
        module_function

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug)
          Array(response.body['models']).map do |entry|
            Model.new(
              id: entry['name'], name: entry['name'], provider: slug,
              created_at: entry['release_date'],
              modalities: { input: ['text'], output: ['judgment'] },
              capabilities: ['judgment'],
              metadata: { description: entry['description'] }.compact
            )
          end
        end
      end
    end
  end
end
