# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'

module RubyLLM
  module ActiveRecord
    # RubyLLM's private, database-backed model registry.
    class Model < ::ActiveRecord::Base # :nodoc:
      self.table_name = 'ruby_llm_models'

      validates :model_id, presence: true, uniqueness: { scope: :provider }
      validates :provider, :name, presence: true

      scope :listed, -> { where(unlisted_at: nil) }
      scope :unlisted, -> { where.not(unlisted_at: nil) }

      UNLISTED_WARNING_LIMIT = 5 # :nodoc:

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
            kept = registry.all.map do |model_info|
              model = find_or_initialize_by(model_id: model_info.id, provider: model_info.provider)
              model.update!(attributes_from_llm(model_info))
              model.id
            end
            unlist(kept)
          end
        end

        def from_llm(model_info)
          new(attributes_from_llm(model_info))
        end

        private

        # A refresh replaces the registry, so models it no longer carries go
        # away. A row an application record points at cannot: deleting it would
        # dangle the reference. That row is stamped unlisted instead, keeping
        # the chats that use it resolvable while the application migrates them.
        def unlist(kept_ids)
          stayed = []
          where.not(id: kept_ids).find_each do |model|
            transaction(requires_new: true) { model.destroy! }
          rescue ::ActiveRecord::InvalidForeignKey
            model.update!(unlisted_at: Time.current) unless model.unlisted_at
            stayed << "#{model.provider}/#{model.model_id}"
          end
          warn_unlisted(stayed)
        end

        def warn_unlisted(names)
          return if names.empty?

          subject = names.size == 1 ? '1 model is' : "#{names.size} models are"
          RubyLLM.logger.warn do
            "#{subject} no longer listed by the provider and may no longer work: #{unlisted_listing(names)}. " \
              'The rows stay because application records still reference them. The provider may have dropped ' \
              'them, or your configured region may not offer them.'
          end
        end

        def unlisted_listing(names)
          extra = names.size - UNLISTED_WARNING_LIMIT
          listing = names.first(UNLISTED_WARNING_LIMIT).join(', ')
          extra.positive? ? "#{listing}, and #{extra} more" : listing
        end

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
            metadata: model_info.metadata,
            unlisted_at: nil
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
          metadata: metadata&.deep_symbolize_keys || {},
          unlisted_at: unlisted_at
        )
      end

      delegate :supports?, :price, :type, :provider_class, :label, :cost_for, :unlisted?, to: :to_llm
    end
  end
end
