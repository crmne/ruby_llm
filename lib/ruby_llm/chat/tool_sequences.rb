# frozen_string_literal: true

module RubyLLM
  class Chat
    module ToolSequences # :nodoc:
      private

      def tool_for(call)
        tool = tools[call.qualified_name.to_sym]
        tool if tool && tool.namespace == call.namespace && tool.name.to_s == call.name.to_s
      end

      def partition_tool_sequences(pending)
        executable = {}
        denied = {}
        pending.each do |id, call|
          decision = if sequence_failed?(call)
                       true
                     elsif !input_pending?(call)
                       execution_decision(call)
                     end
          (decision ? executable : denied)[id] = call unless decision.nil?
        end
        [executable, denied]
      end

      def sequence_blocked?(call)
        earlier_sequence_calls(call).any? do |candidate|
          messages.none? { |message| message.tool_result? && message.tool_call_id == candidate.id }
        end
      end

      def earlier_sequence_calls(call)
        return [] unless call.sequential?

        response = messages.reverse.find { |message| message.tool_calls&.key?(call.id) }
        response.tool_calls.values.take_while { |candidate| candidate.id != call.id }
                .select { |candidate| candidate.sequential? && candidate.namespace == call.namespace }
      end

      def sequence_failed?(call)
        earlier_sequence_calls(call).any? do |candidate|
          result = messages.reverse.find { |message| message.tool_result? && message.tool_call_id == candidate.id }
          result&.tool_error_message
        end
      end
    end
  end
end
