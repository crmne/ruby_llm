# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'

module RubyLLM
  module ActiveRecord
    # RubyLLM's private, database-backed model registry.
    class Model < ::ActiveRecord::Base # :nodoc:
      self.table_name = 'ruby_llm_models'

      validates :model_id, presence: true, uniqueness: { scope: :provider }
      validates :provider, :name, presence: true

      class << self
        def read
          return [] unless table_exists?

          all.map(&:to_llm)
        rescue StandardError => e
          RubyLLM.logger.debug { "Failed to load models from database: #{e.message}, falling back to JSON" }
          []
        end

        def write(registry)
          save_to_database(registry)
        end

        def description
          "database:#{table_name}"
        end

        def refresh!
          RubyLLM.models.refresh!
        end

        def save_to_database(registry = RubyLLM.models)
          transaction do
            registry.all.each do |model_info|
              model = find_or_initialize_by(model_id: model_info.id, provider: model_info.provider)
              model.update!(attributes_from_llm(model_info))
            end
          end
        end

        def from_llm(model_info)
          new(attributes_from_llm(model_info))
        end

        private

        def attributes_from_llm(model_info)
          {
            model_id: model_info.id,
            name: model_info.name,
            provider: model_info.provider,
            family: model_info.family,
            model_created_at: model_info.created_at,
            context_window: model_info.context_window,
            max_output_tokens: model_info.max_output_tokens,
            knowledge_cutoff: model_info.knowledge_cutoff,
            modalities: model_info.modalities.to_h,
            capabilities: model_info.capabilities,
            pricing: model_info.pricing.to_h,
            metadata: model_info.metadata
          }
        end
      end

      def to_llm
        RubyLLM::Model.new(
          id: model_id,
          name: name,
          provider: provider,
          family: family,
          created_at: model_created_at,
          context_window: context_window,
          max_output_tokens: max_output_tokens,
          knowledge_cutoff: knowledge_cutoff,
          modalities: modalities&.deep_symbolize_keys || {},
          capabilities: capabilities,
          pricing: pricing&.deep_symbolize_keys || {},
          metadata: metadata&.deep_symbolize_keys || {}
        )
      end

      delegate :supports?, :price, :type, :provider_class, :label, :cost_for, to: :to_llm
    end
  end
end
