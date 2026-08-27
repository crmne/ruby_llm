# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Provider-owned model catalog reconciliation.
      module Models
        def self.models_dev_alias(model_id, models_dev_by_key, _provider_model = nil)
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
