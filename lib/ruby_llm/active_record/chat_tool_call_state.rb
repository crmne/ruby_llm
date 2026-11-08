# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's tool call state on its
    # +ruby_llm_tool_calls+ rows, read outside the query cache, so every
    # process sees the same state.
    class ChatToolCallState < Chat::ToolCallState # :nodoc:
      def initialize(chat)
        super()
        @chat = chat
        @contested = []
      end

      def input(tool_call)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { @chat.find_tool_call(tool_call.id) }
        record.mcp_state if record&.has_attribute?(:mcp_state)
      end

      def record_input(tool_call, input)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { @chat.find_tool_call(tool_call.id) }
        return if !record&.has_attribute?(:mcp_state) || record.mcp_state == input

        @chat.transaction do
          @chat.forget_stale_cancellation
          record.update!(mcp_state: input)
        end
      end

      def decline_note(tool_call)
        @chat.persisted_decline_note(tool_call)
      end

      def record_decline_note(tool_call, note)
        @chat.record_persisted_decline_note(tool_call.id, note)
      end

      def settle(tool_call, &)
        @chat.settle_persisted_input(tool_call, &)
      end

      def decision(tool_call)
        decided = super
        decided.nil? ? @chat.persisted_tool_call_approval(tool_call) : decided
      end

      def remembered?(call)
        super || @chat.persisted_remembered_tool?(call)
      end

      def claim(requested, executing:)
        @contested = []
        return requested if requested.empty?

        claimed = @chat.claim_persisted_tool_calls(yield, executing:)
        @contested = requested - claimed
        claimed
      end

      def release(ids, stopped_by = nil, finished: false)
        @chat.release_persisted_tool_calls(ids, stopped_by, finished:)
      end

      def started(tool_call)
        @chat.persisted_tool_call_started(tool_call.id)
      end

      def interrupted?(tool_call)
        @chat.persisted_tool_call_interrupted?(tool_call.id)
      end

      def running_elsewhere?(tool_call)
        @contested.include?(tool_call.id) && @chat.tool_call_running_elsewhere?(tool_call)
      end
    end
  end
end
