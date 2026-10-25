# frozen_string_literal: true

module RubyLLM
  class Protocol
    # What a protocol can express of Tool.namespace. A protocol without
    # namespaces raises before a request that has namespaced tools or calls,
    # and none can force a namespaced tool as the tool choice.
    module ToolNamespaces
      # Returns the error a call answers with when an earlier call of its
      # namespace in the same response failed, or +nil+ when the API runs
      # each call on its own. Protocols whose client toolsets run a
      # response's calls in order and stop at the first failure override
      # this.
      def skipped_tool_call_error(_tool_call)
        nil
      end

      def tool_namespaces? # :nodoc:
        false
      end

      def validate_tool_namespaces(messages, tools, tool_prefs = nil) # :nodoc:
        validate_tool_choice_namespace(tools, tool_prefs&.dig(:choice))
        return if tool_namespaces?

        calls = messages.flat_map { |message| (message.tool_calls || {}).values }
        return unless (tools.values + calls).any?(&:namespace)

        raise Error, "#{@provider.name} cannot express tool namespaces with this protocol"
      end

      def validate_tool_choice_namespace(tools, choice) # :nodoc:
        return unless tools[choice]&.namespace

        raise Error, "#{@provider.name} cannot force the namespaced tool #{choice}; use choice: :required instead"
      end
    end
  end
end
