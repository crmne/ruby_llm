# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # A provider-side batch of persisted chats, in RubyLLM's
    # +ruby_llm_batches+ table. RubyLLM.batch writes a row when it submits
    # persisted chats of one class, and RubyLLM::Batch.find reads it back
    # in any process.
    #
    #   RubyLLM::ActiveRecord::Batch.where(completed: false).pluck(:provider_batch_id)
    #
    # Its columns:
    #
    # [+provider_batch_id+] The provider's id for the batch.
    # [+provider+] The provider's slug.
    # [+status+] <tt>"pending"</tt>, <tt>"succeeded"</tt>, <tt>"failed"</tt>, or <tt>"cancelled"</tt>.
    # [+raw_status+] The status as the provider last reported it.
    # [+completed+] Whether the provider has finished the batch.
    # [+request_counts+] The provider's request counts, as a Hash.
    # [+reported_cost+] The cost the provider reported, as a Hash.
    # [+chat_type+, +chat_ids+] The class and ids of the submitted chats.
    #
    # RubyLLM writes these rows. Read and query them, and add scopes and
    # columns of your own, but do not create or update them.
    # Use RubyLLM::Batch to refresh a batch and deliver its results.
    class Batch < Record
      self.table_name = 'ruby_llm_batches'

      STATUSES = %w[pending succeeded failed cancelled].freeze # :nodoc:

      validates :provider_batch_id, :provider, :status, presence: true
      validates :status, inclusion: { in: STATUSES }

      class << self
        def persist(batch, chats) # :nodoc:
          records = Array(chats)
          return unless table_exists?
          return unless persistable_chats?(records)

          create!(
            provider_batch_id: batch.id,
            provider: batch.provider,
            status: batch.status,
            raw_status: batch.raw_status,
            completed: batch.complete?,
            request_counts: batch.request_counts,
            reported_cost: batch.reported_cost&.to_h,
            batch_protocol: batch.batch_protocol,
            chat_type: records.first.class.polymorphic_name,
            chat_ids: records.map(&:id)
          )
        end

        def fetch(id, provider: nil, context: nil) # :nodoc:
          find_record(id, provider:)&.to_llm(context:, store: self)
        end

        def sync(batch) # :nodoc:
          find_record(batch.id, provider: batch.provider)&.sync_from(batch)
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

      # Returns the submitted chat records in submission order, with +nil+
      # for a chat that no longer exists.
      def chats
        klass = chat_type.constantize
        by_id = klass.where(klass.primary_key => Array(chat_ids))
                     .index_by { |chat| chat.public_send(klass.primary_key) }
        Array(chat_ids).map { |id| by_id[id] }
      end

      def to_llm(context: nil, store: nil) # :nodoc:
        config = context&.config || RubyLLM.config
        provider_instance = RubyLLM::Provider.resolve!(provider).new(config)
        records = chats
        RubyLLM::Batch.new(
          provider: provider_instance,
          chats: records.map { |chat| chat&.to_llm },
          delivered: records.each_index.select { |index| answered?(records[index]) },
          delivery: ->(index, failed: false, &deliver) { deliver_once(records[index], failed:, &deliver) },
          id: provider_batch_id,
          raw_status: raw_status,
          completed: completed,
          request_counts: request_counts,
          reported_cost: reported_cost && RubyLLM::Cost.from_h(reported_cost),
          batch_protocol: batch_protocol,
          store: store
        )
      end

      def sync_from(batch) # :nodoc:
        attributes = {
          status: batch.status,
          raw_status: batch.raw_status,
          completed: batch.complete?,
          request_counts: batch.request_counts,
          batch_protocol: batch.batch_protocol
        }
        attributes[:reported_cost] = batch.reported_cost.to_h if batch.reported_cost
        update!(attributes)
      end

      private

      # Two pollers can load a batch before either delivers, so the check
      # is repeated once this one holds the chat.
      def deliver_once(chat, failed: false)
        return yield.then { true } unless chat

        chat.claiming_delivery do
          yield unless failed ? billed_failure?(chat) : answered?(chat)
          true
        end
      end

      # A failed slot adds no message, so its usage row is what marks it.
      def billed_failure?(chat)
        usages = chat.ruby_llm_usages
        usages.klass.uncached do
          usages.where(status: 'failed').where(usages.klass.arel_table[:created_at].gt(created_at)).exists?
        end
      end

      # The chat was awaiting the model when the batch was submitted, so an
      # assistant message newer than the batch answers that turn, whatever
      # the chat went on to stage after it.
      def answered?(chat)
        return false unless chat

        messages = chat.messages_association
        messages.klass.uncached do
          messages.where(role: :assistant).where(messages.klass.arel_table[:created_at].gt(created_at)).exists?
        end
      end
    end
  end
end
