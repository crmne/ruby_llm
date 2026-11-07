# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Keeps a persisted chat's tool call state on its
    # +ruby_llm_tool_calls+ rows, read outside the query cache, so every
    # process sees the same state. It remembers the calls it paused on a
    # task that waits on a person, so a run can tell when another process
    # let one carry on, as a decision on a subagent's call does.
    class ChatToolCallState < Chat::ToolCallState # :nodoc:
      def initialize(chat)
        super()
        @chat = chat
        @contested = []
        @waiting_on_people = {}
      end

      def initialize_copy(source)
        super
        @waiting_on_people = @waiting_on_people.dup
      end

      def input(tool_call)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { @chat.find_tool_call(tool_call.id) }
        record.mcp_state if record&.has_attribute?(:mcp_state)
      end

      def record_input(tool_call, input)
        remember_wait(tool_call, input)
        record = RubyLLM::ActiveRecord::ToolCall.uncached { @chat.find_tool_call(tool_call.id) }
        return if !record&.has_attribute?(:mcp_state) || record.mcp_state == input

        @chat.transaction do
          @chat.forget_stale_cancellation
          record.update!(mcp_state: input)
        end
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
        @chat.release_persisted_tool_calls(ids)
      end

      def running_elsewhere?(tool_call)
        @contested.include?(tool_call.id) && @chat.tool_call_running_elsewhere?(tool_call)
      end

      # Returns whether a call this process paused on a person no longer
      # waits on one, and forgets those calls.
      def wait_ended_elsewhere?
        ended = @waiting_on_people.values.reject { |tool_call| waits_on_person?(input(tool_call)) }
        ended.each { |tool_call| @waiting_on_people.delete(tool_call.id) }
        ended.any?
      end

      private

      def remember_wait(tool_call, input)
        if waits_on_person?(input)
          @waiting_on_people[tool_call.id] = tool_call
        else
          @waiting_on_people.delete(tool_call.id)
        end
      end

      def waits_on_person?(input)
        input&.dig('task', 'status') == 'input_required'
      end
    end
  end
end
