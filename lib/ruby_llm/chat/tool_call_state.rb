# frozen_string_literal: true

module RubyLLM
  class Chat
    # Holds what a chat knows about its tool calls beyond the transcript, in
    # memory. A copy of the chat gets a copy of the state. The Rails
    # integration swaps in ActiveRecord::ChatToolCallState, which keeps it
    # on the tool call records so any process can read it.
    class ToolCallState # :nodoc:
      def initialize
        @inputs = {}
        @decisions = {}
        @remembered = []
        @spent_escalations = []
      end

      def initialize_copy(source)
        super
        @inputs = @inputs.dup
        @decisions = @decisions.dup
        @remembered = @remembered.dup
        @spent_escalations = @spent_escalations.dup
      end

      def input(tool_call)
        @inputs[tool_call.id]
      end

      def record_input(tool_call, input)
        @inputs[tool_call.id] = input
      end

      # Replaces the input +tool_call+ is paused on with what the block
      # returns for it, while the call is still paused.
      def settle(tool_call)
        input = @inputs[tool_call.id]
        @inputs[tool_call.id] = yield(input) if input
      end

      def record_decision(id, decision)
        @decisions[id] = decision
      end

      def decision(tool_call)
        @decisions[tool_call.id]
      end

      def denied?(tool_call)
        @decisions[tool_call.id] == false
      end

      def remember(identity)
        @remembered |= [identity]
      end

      def remembered?(call)
        @remembered.include?([call.namespace, call.name.to_s])
      end

      def escalation_spent?(tool_call)
        @spent_escalations.include?(tool_call.id)
      end

      def spend_escalation(tool_call)
        @spent_escalations << tool_call.id
      end

      def claim(requested, **)
        requested
      end

      def release(_ids); end

      def running_elsewhere?(_tool_call)
        false
      end
    end
  end
end
