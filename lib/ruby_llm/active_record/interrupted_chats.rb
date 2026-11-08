# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Builds ChatMethods.interrupted: the chats whose conversation loop
    # stopped with work left and that no process holds. It mirrors
    # RubyLLM::Chat#complete? and #waiting? in SQL over the rows RubyLLM
    # persists, so it never loads a transcript.
    #
    # The latest response is the newest message that isn't a system
    # message, a tool result, or the blank reply a run creates before the
    # provider answers. Its calls without a result are open, and an open
    # call blocks while it waits for approval, while a process holds its
    # claim, or while its +mcp_state+ holds a task or an unanswered
    # question. Databases query JSON in different ways, so Ruby reads the
    # +mcp_state+ of the open calls on the latest responses of the chats
    # SQL found, and the relation leaves out those whose open calls all
    # block. It skips the query cache, since a job polls it for what other
    # processes wrote. Without claim columns no row says whether a process
    # holds a chat, so no chat counts as interrupted.
    class InterruptedChats # :nodoc:
      BLANK_COLUMNS = %w[continuation thinking_text content_raw raw_content raw_reasoning].freeze

      def initialize(relation)
        @relation = relation
        @chat = relation.klass
        @messages = @chat.reflect_on_association(@chat.messages_association_name)
        @now = Time.current
      end

      def relation
        return @relation.none unless claims?

        found = @relation.where(unclaimed).where(sql(work))
        paused = paused_calls(found)
        found.where.not(sql(waiting(paused.any?), paused:)).skip_query_cache!
      end

      private

      def claims?
        (%w[claim_token claimed_until] - @chat.column_names).empty?
      end

      def unclaimed
        sql = "#{chat_column(:claimed_until)} IS NULL OR #{chat_column(:claimed_until)} <= :now"
        sql = "(#{sql}) AND #{chat_column(:cancelled)} = :no" if @chat.column_names.include?('cancelled')
        sql(sql)
      end

      def work
        conditions = [
          "EXISTS (#{latest('l') { |a| conversation(a) }} AND (#{needs_reply('l')}))",
          "EXISTS (#{latest('r') { |a| response(a) }} AND EXISTS (#{open_calls('r')}))"
        ]
        conditions << "EXISTS (#{queued})" if QueuedMessage.table_exists?
        conditions.join(' OR ')
      end

      def waiting(paused)
        <<~SQL.squish
          EXISTS (#{latest('r') { |a| response(a) }} AND EXISTS (#{open_calls('r')})
            AND NOT EXISTS (#{open_calls('r')} AND NOT (#{blocked('r_c', paused)})))
        SQL
      end

      def paused_calls(found)
        return [] unless tool_call_column?(:mcp_state)

        responses = found.select(Arel.sql(sql("(#{newest('p') { |a| response(a) }})")))
        states = ToolCall.uncached do
          ToolCall.where(message_type:, message_id: responses, result_id: nil)
                  .pluck(:id, :mcp_state)
        end
        states.filter_map { |id, state| id if paused?(state) }
      end

      def paused?(state)
        return false unless state

        state.key?('task') || Array(state['requests']).any? { |request| request['response'].nil? }
      end

      def needs_reply(name)
        role = column(name, :role)
        replies = ["#{role} = 'user'", "(#{role} = 'tool' AND #{round_goes_on(name)})"]
        if message_column?(:continuation)
          replies << "(#{role} = 'assistant' AND #{column(name, :continuation)} IS NOT NULL)"
        end
        replies.join(' OR ')
      end

      def round_goes_on(name)
        return '1 = 1' unless message_column?(:finish_reason)

        <<~SQL.squish
          COALESCE(#{column(name, :finish_reason)}, '') <> 'cancelled'
          AND NOT EXISTS (SELECT 1 FROM #{ToolCall.quoted_table_name} h_c
            INNER JOIN #{@messages.klass.quoted_table_name} h ON #{column('h', message_key)} = #{column('h_c', :result_id)}
            WHERE #{column('h_c', :message_type)} = :message_type
            AND #{column('h_c', :message_id)} = (#{newest('h_r') { |a| response(a) }})
            AND #{column('h', :finish_reason)} = 'halted')
        SQL
      end

      def blocked(name, paused)
        conditions = ['1 = 0']
        conditions << "COALESCE(#{column(name, :approval)}, '') = 'pending'" if tool_call_column?(:approval)
        if tool_call_column?(:claimed_until)
          conditions << "(#{column(name, :claimed_until)} IS NOT NULL AND #{column(name, :claimed_until)} > :now)"
        end
        conditions << "#{column(name, :id)} IN (:paused)" if paused
        conditions.join(' OR ')
      end

      def latest(name, &)
        "SELECT 1 FROM #{@messages.klass.quoted_table_name} #{name} " \
          "WHERE #{column(name, message_key)} = (#{newest("#{name}_l", &)})"
      end

      def newest(name, &condition)
        @messages.klass.unscoped.from("#{@messages.klass.quoted_table_name} #{name}")
                 .where("#{chat_key(name)} AND #{condition.call(name)}")
                 .order(Arel.sql("#{column(name, :created_at)} DESC, #{column(name, message_key)} DESC"))
                 .limit(1).select(Arel.sql(column(name, message_key))).to_sql
      end

      def conversation(name)
        "#{column(name, :role)} <> 'system' AND NOT (#{blank(name)})"
      end

      def response(name)
        "#{conversation(name)} AND #{column(name, :role)} <> 'tool'"
      end

      def blank(name)
        conditions = ["#{column(name, :role)} = 'assistant'", "TRIM(COALESCE(#{column(name, :content)}, '')) = ''",
                      "NOT EXISTS (#{tool_calls(name)})"]
        BLANK_COLUMNS.each do |blank_column|
          conditions << "#{column(name, blank_column)} IS NULL" if message_column?(blank_column)
        end
        conditions << "NOT EXISTS (#{attachments(name)})" if attachments?
        conditions.join(' AND ')
      end

      def messages_of_chat(name)
        "SELECT 1 FROM #{@messages.klass.quoted_table_name} #{name} WHERE #{chat_key(name)}"
      end

      def chat_key(name)
        "#{column(name, @messages.foreign_key)} = #{chat_column(@chat.primary_key)}"
      end

      def tool_calls(name)
        "SELECT 1 FROM #{ToolCall.quoted_table_name} #{name}_c WHERE #{column("#{name}_c", :message_type)} = " \
          ":message_type AND #{column("#{name}_c", :message_id)} = #{column(name, message_key)}"
      end

      def open_calls(name)
        "#{tool_calls(name)} AND #{column("#{name}_c", :result_id)} IS NULL"
      end

      def attachments(name)
        "SELECT 1 FROM #{ActiveStorage::Attachment.quoted_table_name} #{name}_a " \
          "WHERE #{column("#{name}_a", :record_type)} = :message_type " \
          "AND #{column("#{name}_a", :record_id)} = #{column(name, message_key)} " \
          "AND #{column("#{name}_a", :name)} = 'attachments'"
      end

      def queued
        "SELECT 1 FROM #{QueuedMessage.quoted_table_name} q WHERE #{column('q', :chat_type)} = :chat_type " \
          "AND #{column('q', :chat_id)} = #{chat_column(@chat.primary_key)}"
      end

      def sql(fragment, paused: [])
        @chat.sanitize_sql_array([fragment, { now: @now, no: false, paused:, message_type:,
                                              chat_type: @chat.polymorphic_name }])
      end

      def message_type = @messages.klass.polymorphic_name
      def message_key = @messages.klass.primary_key
      def message_column?(name) = @messages.klass.column_names.include?(name.to_s)
      def tool_call_column?(name) = ToolCall.column_names.include?(name.to_s)

      def attachments?
        @messages.klass.reflect_on_association(:attachments_attachments)
      end

      def column(table, name) = "#{table}.#{@chat.connection.quote_column_name(name)}"
      def chat_column(name) = "#{@chat.quoted_table_name}.#{@chat.connection.quote_column_name(name)}"
    end
  end
end
