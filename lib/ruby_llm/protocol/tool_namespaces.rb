# frozen_string_literal: true

module RubyLLM
  class Protocol
    # What a protocol can express of Tool.namespace. A protocol without
    # namespaces raises before a request that has namespaced tools or calls.
    module ToolNamespaces
      # Raises for a forced tool choice that names a namespaced tool, for
      # protocols whose tool choice cannot name one.
      def self.validate_tool_choice(tools, choice) # :nodoc:
        return unless tools[choice]&.namespace

        raise Error, "The namespaced tool #{choice} cannot be forced; use choice: :required instead"
      end

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

      def validate_tool_namespaces(messages, tools) # :nodoc:
        return if tool_namespaces?

        calls = messages.flat_map { |message| (message.tool_calls || {}).values }
        return unless (tools.values + calls).any?(&:namespace)

        raise Error, "#{@provider.name} cannot express tool namespaces with this protocol"
      end
    end
  end
end
