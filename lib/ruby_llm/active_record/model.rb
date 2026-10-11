# frozen_string_literal: true

require 'active_support/core_ext/module/delegation'

module RubyLLM
  module ActiveRecord
    # A row of the +ruby_llm_models+ table, one per registry entry. Chats
    # point at it through +belongs_to :model+. The +listed+ scope returns the
    # models the provider still serves; +unlisted+ returns the ones kept only
    # because a chat references them.
    class Model < Record
      self.table_name = 'ruby_llm_models'

      validates :model_id, presence: true, uniqueness: { scope: :provider }
      validates :provider, :name, presence: true

      scope :listed, -> { where(unlisted_at: nil) }
      scope :unlisted, -> { where.not(unlisted_at: nil) }

      UNLISTED_WARNING_LIMIT = 5 # :nodoc:

      class << self
        def read # :nodoc:
          return [] unless table_exists?

          all.map(&:to_llm)
        rescue StandardError => e
          RubyLLM.logger.debug { "Failed to load models from database: #{e.message}, falling back to JSON" }
          []
        end

        def write(registry) # :nodoc:
          save_to_database(registry)
        end

        def description # :nodoc:
          "database:#{table_name}"
        end

        def refresh # :nodoc:
          RubyLLM.models.refresh
        end

        def save_to_database(registry = RubyLLM.models) # :nodoc:
          rows = registry.all.index_by { |model_info| [model_info.provider, model_info.id] }
                         .transform_values { |model_info| attributes_from_llm(model_info) }
          validate_incomplete(rows.values)

          transaction(requires_new: true) do
            upsert_all(rows.values, unique_by: registry_key) if rows.any?
            unlist(pluck(:id, :provider, :model_id).reject { |_id, *key| rows.key?(key) }.map(&:first))
          end
        end

        def from_llm(model_info) # :nodoc:
          new(attributes_from_llm(model_info))
        end

        private

        # A refresh replaces the registry, so models it no longer carries go
        # away. A row an application record points at cannot: deleting it would
        # dangle the reference. That row is stamped unlisted instead, keeping
        # the chats that use it resolvable while the application migrates them.
        def unlist(dropped_ids)
          stayed = []
          where(id: dropped_ids).find_each do |model|
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

        # upsert_all skips validations. An entry missing a required value goes
        # through them on its own, so it raises RecordInvalid as a save would.
        def validate_incomplete(rows)
          rows.each do |attributes|
            new(attributes).validate! if attributes.values_at(:model_id, :provider, :name).any?(&:blank?)
          end
        end

        # Active Record's MySQL adapter rejects a named conflict target;
        # MySQL matches every unique index on its own.
        def registry_key
          %i[provider model_id] if connection_pool.with_connection(&:supports_insert_conflict_target?)
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

      # Returns this registry record as a RubyLLM::Model.
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

      # Registry readers answered from the RubyLLM::Model value of the row.
      delegate :supports?, :price, :type, :provider_class, :label, :cost_for, :unlisted?, to: :to_llm
    end
  end
end
