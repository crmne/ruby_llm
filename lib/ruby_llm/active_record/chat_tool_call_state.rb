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
        record = @chat.find_tool_call(tool_call.id)
        record.update!(mcp_state: input) if record&.has_attribute?(:mcp_state)
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

      def release(ids)
        @chat.release_persisted_tool_calls(ids) if ids.any?
      end

      def running_elsewhere?(tool_call)
        @contested.include?(tool_call.id) && @chat.tool_call_running_elsewhere?(tool_call)
      end
    end
  end
end
