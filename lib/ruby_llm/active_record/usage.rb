# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # One provider attempt in RubyLLM's usage ledger, the +ruby_llm_usages+
    # table. RubyLLM writes a row for every billable attempt, including
    # retries, cancelled streams, and one-shot operations without a chat.
    # A write that fails is logged and skipped, so it never breaks the
    # operation.
    #
    #   chat.ruby_llm_usages.sum(:total_cost)
    #   RubyLLM::ActiveRecord::Usage.where(owner: current_user).group(:operation).sum(:total_cost)
    #
    # Each row has optional polymorphic +chat+, +message+, and +owner+
    # associations. The +chronological+ scope orders rows oldest first.
    # Its columns:
    #
    # [+operation+] What ran: <tt>"chat"</tt>, <tt>"embedding"</tt>, <tt>"image"</tt>,
    #               <tt>"speech"</tt>, <tt>"transcription"</tt>, and so on.
    # [+provider+] The provider's slug.
    # [+model+] The model the provider ran, or its own resource identifier.
    # [+status+] <tt>"pending"</tt>, <tt>"succeeded"</tt>, <tt>"failed"</tt>, or <tt>"cancelled"</tt>.
    # [+input_tokens+, +output_tokens+, +cache_read_tokens+, +cache_write_tokens+, +thinking_tokens+]
    #   Token counts, in the bucket the provider bills each at.
    # [+characters+, +audio_seconds+, +search_units+] Units billed instead of tokens.
    # [+server_tool_use+] Counts of provider-run tool calls, as a Hash.
    # [+input_cost+, +output_cost+, +cache_read_cost+, +cache_write_cost+, +thinking_cost+]
    #   The cost of each token bucket, frozen when the attempt finished.
    # [+characters_cost+, +audio_seconds_cost+, +search_units_cost+] The cost of each unit.
    # [+total_cost+] The attempt's total cost, or +nil+ when it is unknown.
    # [+workflow_id+, +workflow_name+, +workflow_step_id+, +workflow_step_name+]
    #   The workflow and step that made the attempt, if any.
    #
    # RubyLLM writes these rows. Read and query them, and add scopes and
    # columns of your own, but do not create or update them.
    class Usage < Record
      self.table_name = 'ruby_llm_usages'

      WORKFLOW_COLUMNS = %i[workflow_id workflow_name workflow_step_id workflow_step_name].freeze # :nodoc:
      UNIT_COLUMNS = ::RubyLLM::Cost::UNITS.flat_map { |unit| [unit, :"#{unit}_cost"] }.freeze # :nodoc:

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
      def self.record(entry) # :nodoc:
        return unless entry.model

        connection_pool.with_connection do
          next unless ledger_available?

          transaction(requires_new: true) { create!(attributes_for(entry)) }
        end
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not record #{entry.operation} usage: #{e.class}: #{e.message}")
        nil
      end

      def self.ledger_available? # :nodoc:
        table_exists? && columns_hash['chat_id']&.null
      end

      def self.attributes_for(entry) # :nodoc:
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
        attributes.merge!(unit_attributes(tokens, cost)) if column_names.include?('search_units')
        attributes[:owner] = entry.owner if entry.owner.is_a?(::ActiveRecord::Base) && column_names.include?('owner_id')
        attributes.merge!(workflow_attributes(entry.workflow)) if column_names.include?('workflow_id')
        attributes
      end

      def self.unit_attributes(tokens, cost) # :nodoc:
        ::RubyLLM::Cost::UNITS.each_with_object({}) do |unit, attributes|
          attributes[unit] = tokens.public_send(unit)
          attributes[:"#{unit}_cost"] = cost.public_send(unit)
        end
      end

      def self.workflow_attributes(workflow) # :nodoc:
        workflow.to_h.slice(*WORKFLOW_COLUMNS)
      end

      def self.owner_preload # :nodoc:
        column_names.include?('owner_id') ? :owner : []
      end

      # Returns the attempt's counts as RubyLLM::Tokens.
      def tokens
        RubyLLM::Tokens.new(
          input: input_tokens,
          output: output_tokens,
          cache_read: cache_read_tokens,
          cache_write: cache_write_tokens,
          thinking: thinking_tokens,
          **recorded_units,
          server_tool_use: (self[:server_tool_use] if has_attribute?(:server_tool_use))
        )
      end

      # Returns the attempt's frozen cost as RubyLLM::Cost.
      def cost
        recorded = {
          input: input_cost,
          output: output_cost,
          cache_read: cache_read_cost,
          cache_write: cache_write_cost,
          thinking: thinking_cost,
          **recorded_units(suffix: '_cost'),
          total: total_cost
        }.compact
        RubyLLM::Cost.from_h(recorded, tokens: tokens)
      end

      def usage_available? # :nodoc:
        tokens.to_h.any?
      end

      def cost_available? # :nodoc:
        !total_cost.nil?
      end

      def to_entry # :nodoc:
        ::RubyLLM::Accounting::Usage::Entry.new(
          operation: operation,
          provider: provider,
          model: model,
          status: status,
          tokens: tokens,
          cost: cost,
          message: message,
          owner: (owner if has_attribute?(:owner_id)),
          workflow: workflow_context
        )
      end

      private

      def recorded_units(suffix: nil)
        ::RubyLLM::Cost::UNITS.each_with_object({}) do |unit, units|
          column = :"#{unit}#{suffix}"
          units[unit] = self[column] if has_attribute?(column)
        end
      end

      def workflow_context
        context = WORKFLOW_COLUMNS.select { |name| has_attribute?(name) }.index_with { |name| self[name] }.compact
        context unless context.empty?
      end
    end
  end
end
