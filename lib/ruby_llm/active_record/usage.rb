# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # RubyLLM's private normalized persistence for one provider attempt.
    class Usage < Record # :nodoc:
      self.table_name = 'ruby_llm_usages'

      belongs_to :chat, polymorphic: true, optional: true
      belongs_to :message, polymorphic: true, optional: true
      belongs_to :owner, polymorphic: true, optional: true

      validates :operation, inclusion: { in: ::RubyLLM::Accounting::Usage::Entry::OPERATIONS.map(&:to_s) }
      validates :status, inclusion: { in: ::RubyLLM::Accounting::Usage::Entry::STATUSES.map(&:to_s) }
      validates :provider, :model, presence: true

      scope :chronological, -> { order(created_at: :asc, id: :asc) }

      # Writes an entry that belongs to no chat record, attributed to its
      # owner. A ledger that cannot store such rows yet is skipped, and a
      # failed write is logged so it never breaks the operation that billed
      # it. A savepoint keeps a failed insert from aborting the caller's
      # transaction, and a thread that held no connection gives back the
      # one it borrowed.
      def self.record(entry)
        return unless entry.model

        connection_pool.with_connection do
          next unless ledger_available?

          transaction(requires_new: true) { create!(attributes_for(entry)) }
        end
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not record #{entry.operation} usage: #{e.class}: #{e.message}")
        nil
      end

      def self.ledger_available?
        table_exists? && columns_hash['chat_id']&.null
      end

      def self.attributes_for(entry)
        tokens = entry.tokens
        cost = entry.cost
        attributes = {
          operation: entry.operation,
          provider: entry.provider,
          model: entry.model,
          status: entry.status,
          input_tokens: tokens.input,
          output_tokens: tokens.output,
          cache_read_tokens: tokens.cache_read,
          cache_write_tokens: tokens.cache_write,
          thinking_tokens: tokens.thinking,
          input_cost: cost.input,
          output_cost: cost.output,
          cache_read_cost: cost.cache_read,
          cache_write_cost: cost.cache_write,
          thinking_cost: cost.thinking,
          total_cost: cost.total
        }
        attributes[:server_tool_use] = tokens.server_tool_use if column_names.include?('server_tool_use')
        attributes[:owner] = entry.owner if column_names.include?('owner_id')
        attributes
      end

      def tokens
        RubyLLM::Tokens.new(
          input: input_tokens,
          output: output_tokens,
          cache_read: cache_read_tokens,
          cache_write: cache_write_tokens,
          thinking: thinking_tokens,
          server_tool_use: (self[:server_tool_use] if has_attribute?(:server_tool_use))
        )
      end

      def cost
        recorded = {
          input: input_cost,
          output: output_cost,
          cache_read: cache_read_cost,
          cache_write: cache_write_cost,
          thinking: thinking_cost,
          total: total_cost
        }.compact
        RubyLLM::Cost.from_h(recorded, tokens: tokens)
      end

      def usage_available?
        tokens.to_h.any?
      end

      def cost_available?
        !total_cost.nil?
      end

      def to_entry
        ::RubyLLM::Accounting::Usage::Entry.new(
          operation: operation,
          provider: provider,
          model: model,
          status: status,
          tokens: tokens,
          cost: cost,
          message: message
        )
      end
    end
  end
end
