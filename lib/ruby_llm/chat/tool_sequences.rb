# frozen_string_literal: true

module RubyLLM
  class Chat
    # Tool lookup by namespace and the ordered batches of client toolsets.
    # When the provider runs a namespace's calls in one response in order,
    # each call waits for the ones before it, and once one fails the rest
    # are answered with the provider's skipped-call error instead of
    # running.
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
          decision = if skipped_result(call)
                       true
                     elsif !input_pending?(call)
                       execution_decision(call)
                     end
          (decision ? executable : denied)[id] = call unless decision.nil?
        end
        [executable, denied]
      end

      def ordered?(call)
        !skipped_tool_call_error(call).nil?
      end

      def skipped_result(call)
        error = skipped_tool_call_error(call)
        { error: } if error && sequence_failed?(call)
      end

      def skipped_tool_call_error(call)
        @provider.skipped_tool_call_error(call, model: @model, protocol: @protocol)
      end

      def sequence_blocked?(call)
        earlier_sequence_calls(call).any? { |candidate| tool_result_for(candidate).nil? }
      end

      def sequence_failed?(call)
        earlier_sequence_calls(call).any? { |candidate| tool_result_for(candidate)&.tool_error_message }
      end

      def earlier_sequence_calls(call)
        return [] unless ordered?(call)

        response = messages.reverse.find { |message| message.tool_calls&.key?(call.id) }
        response.tool_calls.values.take_while { |candidate| candidate.id != call.id }
                .select { |candidate| candidate.namespace == call.namespace }
      end

      def tool_result_for(call)
        messages.reverse.find { |message| message.tool_result? && message.tool_call_id == call.id }
      end
    end
  end
end
