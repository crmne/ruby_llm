# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # RubyLLM's private normalized persistence for one provider attempt.
    class Usage < ::ActiveRecord::Base # :nodoc:
      self.table_name = 'ruby_llm_usage_entries'

      belongs_to :chat, polymorphic: true
      belongs_to :message, polymorphic: true, optional: true

      validates :operation, inclusion: { in: ::RubyLLM::Usage::Entry::OPERATIONS.map(&:to_s) }
      validates :status, inclusion: { in: ::RubyLLM::Usage::Entry::STATUSES.map(&:to_s) }
      validates :provider, :model, presence: true

      scope :chronological, -> { order(created_at: :asc, id: :asc) }

      def tokens
        RubyLLM::Tokens.build(
          input: input_tokens,
          output: output_tokens,
          cache_read: cache_read_tokens,
          cache_write: cache_write_tokens,
          thinking: thinking_tokens
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

      def to_entry
        ::RubyLLM::Usage::Entry.new(
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
