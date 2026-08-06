# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # RubyLLM's private persistence for provider-side batches.
    class Batch < ::ActiveRecord::Base # :nodoc:
      self.table_name = 'ruby_llm_batches'

      validates :provider_batch_id, :provider, presence: true

      class << self
        def persist(batch, chats)
          records = Array(chats)
          return unless table_exists?
          return unless persistable_chats?(records)

          create!(
            provider_batch_id: batch.id,
            provider: batch.provider_slug,
            status: batch.status,
            completed: batch.complete?,
            request_counts: batch.request_counts,
            batch_protocol: batch.batch_protocol,
            chat_type: records.first.class.polymorphic_name,
            chat_ids: records.map(&:id)
          )
        end

        def fetch(id, provider: nil, context: nil)
          find_record(id, provider:)&.to_llm(context:, store: self)
        end

        def sync(batch)
          find_record(batch.id, provider: batch.provider_slug)&.sync_from(batch)
        end

        private

        def find_record(id, provider: nil)
          return unless table_exists?

          scope = where(provider_batch_id: id)
          scope = scope.where(provider: provider.to_s) if provider
          scope.order(id: :desc).first
        end

        def persistable_chats?(records)
          records.all? { |chat| persisted_chat?(chat) } && records.map(&:class).uniq.one?
        end

        def persisted_chat?(chat)
          chat.respond_to?(:to_llm) && chat.respond_to?(:id) && chat.persisted?
        end
      end

      def chats
        klass = chat_type.constantize
        by_id = klass.where(klass.primary_key => Array(chat_ids))
                     .index_by { |chat| chat.public_send(klass.primary_key) }
        Array(chat_ids).map { |id| by_id[id] }
      end

      def to_llm(context: nil, store: nil)
        config = context&.config || RubyLLM.config
        provider_instance = RubyLLM::Provider.resolve!(provider).new(config)
        RubyLLM::Batch.new(
          provider: provider_instance,
          chats: chats.map { |chat| chat&.to_llm },
          id: provider_batch_id,
          status: status,
          completed: completed,
          request_counts: request_counts,
          batch_protocol: batch_protocol,
          store: store
        )
      end

      def sync_from(batch)
        update!(
          status: batch.status,
          completed: batch.complete?,
          request_counts: batch.request_counts,
          batch_protocol: batch.batch_protocol
        )
      end
    end
  end
end
