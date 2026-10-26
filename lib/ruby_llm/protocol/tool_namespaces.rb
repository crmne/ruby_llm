# frozen_string_literal: true

module RubyLLM
  class Protocol
    # How a protocol carries Tool.namespace. A namespace the API has no
    # native form for is folded into the function name,
    # <tt>namespace_name</tt>, and the calls that come back under that name
    # are mapped back onto the namespace and the tool's own name.
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

      def native_tool_namespace?(_namespace) # :nodoc:
        false
      end

      def complete(messages, tools:, **options, &block) # :nodoc:
        restore_tool_namespaces(super, tools)
      end

      def render(messages, tools:, **) # :nodoc:
        super(messages.map { |message| flatten_message(message) }, tools: flatten_tools(tools), **)
      end

      def count_tokens(messages, tools:, **) # :nodoc:
        super(messages.map { |message| flatten_message(message) }, tools: flatten_tools(tools), **)
      end

      private

      def flatten_tools(tools)
        tools.transform_values { |tool| flattened?(tool) ? Tool::Flattened.wrap(tool) : tool }
      end

      def restore_tool_namespaces(message, tools)
        return message unless message.is_a?(Message) && message.tool_call?

        calls = message.tool_calls.transform_values do |call|
          tool = tools[call.name.to_sym] if call.namespace.nil?
          tool && flattened?(tool) ? restore_tool_call(call, tool) : call
        end
        message.with_tool_calls(calls)
      end

      def flattened?(tool_or_call)
        !tool_or_call.namespace.nil? && !native_tool_namespace?(tool_or_call.namespace)
      end

      def flatten_message(message)
        return message unless message.tool_calls&.values&.any? { |call| flattened?(call) }

        message.with_tool_calls(message.tool_calls.transform_values { |call| flatten_tool_call(call) })
      end

      def flatten_tool_call(call)
        return call unless flattened?(call)

        rebuild_tool_call(call, name: call.qualified_name, namespace: nil)
      end

      def restore_tool_call(call, tool)
        rebuild_tool_call(call, name: tool.name, namespace: tool.namespace)
      end

      def rebuild_tool_call(call, name:, namespace:)
        ToolCall.new(id: call.id, provider_call_id: call.provider_call_id, name:, namespace:,
                     arguments: call.arguments, thought_signature: call.thought_signature, remote: call.remote?)
      end
    end
  end
end
