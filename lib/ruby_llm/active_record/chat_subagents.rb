# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Reaches the chats that subagents work in for a persisted chat, through
    # the +subagent_chat+ of its unanswered tool calls, so every process
    # sees what they wait for. A chat lists their approvals with its own,
    # records decisions on them, and stops their runs when it is cancelled.
    # A decision on a subagent's call lets the calls that wait on it carry
    # on: their tasks stop waiting on a person once no approval is left.
    module ChatSubagents # :nodoc:
      # Records +decision+ on +record+, one of this chat's calls, for a chat
      # this one works for. The decision is only persisted: building this
      # chat to decide would need its agent's configuration.
      def decide_tool_call(record, decision) # :nodoc:
        RubyLLM::Chat.remembered_tool_identity(record.to_llm) if decision == 'remembered' && record.result_id.nil?
        record_tool_call_decision(record, decision)
        wake_callers
        self
      end

      private

      def subagent_chats(chat = self)
        calls = RubyLLM::ActiveRecord::ToolCall
        return [] unless calls.subagent_chats?

        association = chat.messages_association
        calls.uncached do
          calls.where(message_type: association.klass.polymorphic_name, message_id: association.select(:id),
                      result_id: nil).includes(:subagent_chat).filter_map(&:subagent_chat)
        end
      end

      def nested_subagent_chats
        found = []
        waiting = subagent_chats
        while (chat = waiting.shift)
          found << chat
          waiting.concat(subagent_chats(chat))
        end
        found
      end

      def subagent_pending_approvals?
        subagent_chats.any? { |chat| chat.pending_approvals.exists? }
      end

      def with_subagent_approvals(own)
        calls = RubyLLM::ActiveRecord::ToolCall
        scopes = [own, *subagent_chats.map(&:pending_approvals)]
        scopes.map { |scope| calls.where(id: scope.unscope(:order).select(:id)) }
              .reduce(:or).order(:created_at, :id).skip_query_cache!
      end

      def deciding(tool_call, decision)
        record, chat = tool_call_and_chat(tool_call)
        return tap { chat.decide_tool_call(record, decision) } unless chat.equal?(self)

        yield record
        wake_callers
        self
      end

      def tool_call_and_chat(tool_call)
        id = tool_call_id_of(tool_call)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { find_tool_call(id) }
        return [record, self] if record

        nested_subagent_chats.each do |chat|
          record = RubyLLM::ActiveRecord::ToolCall.uncached { chat.find_tool_call(id) }
          return [record, chat] if record
        end
        raise ArgumentError, "Unknown tool call: #{id.inspect}"
      end

      def wake_callers
        chat = self
        waiting = false
        while (call = calling_tool_call(chat))
          waiting ||= chat.pending_approvals.exists?
          calling_chat = call.message.chat_association
          calling_chat.transaction do
            calling_chat.forget_stale_cancellation
            stop_waiting_on_person(call) unless waiting
          end
          chat = calling_chat
        end
      end

      def calling_tool_call(chat)
        calls = RubyLLM::ActiveRecord::ToolCall
        return unless calls.subagent_chats?

        calls.uncached { calls.where(subagent_chat: chat, result_id: nil).includes(:message).first }
      end

      def stop_waiting_on_person(call)
        state = call.mcp_state
        return unless state&.dig('task', 'status') == 'input_required'

        call.update!(mcp_state: state.merge('task' => state['task'].merge('status' => 'working')))
      end
    end
  end
end
