# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Provider-owned model catalog reconciliation.
      module Models
        SNAPSHOT_BASES = {
          'gpt-3.5-turbo-0125' => 'gpt-3.5-turbo',
          'gpt-3.5-turbo-1106' => 'gpt-3.5-turbo',
          'gpt-4-0314' => 'gpt-4',
          'gpt-4-0613' => 'gpt-4',
          'gpt-4-turbo-2024-04-09' => 'gpt-4-turbo',
          'o1-2024-12-17' => 'o1',
          'o3-mini-2025-01-31' => 'o3-mini'
        }.freeze

        def self.models_dev_alias(model_id, models_dev_by_key, _provider_model = nil)
          base_id = SNAPSHOT_BASES[model_id]
          if base_id
            source = models_dev_by_key["openai:#{base_id}"]
            return Model.new(source.to_h.merge(id: model_id)) if source
          end

          match = model_id.match(/\A(.+)-(\d{4}-\d{2}-\d{2})\z/)
          return unless match

          source = models_dev_by_key["openai:#{match[1]}"]
          return unless source&.created_at
          return unless source.created_at.to_date.to_s == match[2]

          Model.new(source.to_h.merge(id: model_id))
        end
      end
    end
  end
end
