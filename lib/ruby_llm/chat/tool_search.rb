# frozen_string_literal: true

module RubyLLM
  class Chat
    # Deferred tool registration and the tool set rendered for the request.
    module ToolSearch # :nodoc:
      private

      def register_tool(tool, defer:)
        tool_instance = tool.is_a?(Class) ? tool.new : tool
        name = tool_instance.name.to_sym
        @tools[name] = tool_instance
        if defer_tool?(tool_instance, defer)
          @deferred_tool_names[name] = true
        else
          @deferred_tool_names.delete(name)
        end
      end

      def defer_tool?(tool, explicit)
        return explicit ? true : false unless explicit.nil?

        tool.respond_to?(:deferred?) && tool.deferred?
      end

      # Tools the model has loaded stay deferred on the wire so the tools
      # array is the same on every turn and the provider's prompt cache
      # survives.
      def effective_tools
        return tools if @deferred_tool_names.empty? || !@provider.supports_deferred_tools?(@model, protocol: @protocol)

        tools.to_h do |name, tool|
          [name, @deferred_tool_names.key?(name) ? Tool::Registration.new(tool, deferred: true) : tool]
        end
      end
    end
  end
end
