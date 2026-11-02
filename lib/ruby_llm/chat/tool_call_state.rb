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
      end

      def initialize_copy(source)
        super
        @inputs = @inputs.dup
      end

      def input(tool_call)
        @inputs[tool_call.id]
      end

      def record_input(tool_call, input)
        @inputs[tool_call.id] = input
      end
    end
  end
end
