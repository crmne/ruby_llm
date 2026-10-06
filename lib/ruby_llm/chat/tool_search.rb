# frozen_string_literal: true

module RubyLLM
  class Chat
    # Deferred tool registration and the tool set rendered for the request.
    module ToolSearch # :nodoc:
      private

      def deferred_tool_names
        names = @tool_deferrals.filter_map { |name, deferred| name if deferred }
        mcp.each do |server|
          explicit = @mcp_deferrals[server.name.to_sym]
          server.tools.each do |tool|
            names << tool.name.to_sym if explicit.nil? ? server.defers?(tool) : explicit
          end
        end
        names
      end

      def request_tools
        deferred = deferred_tool_names
        tools.to_h { |name, tool| [name, deferred.include?(name) ? Tool::Deferred.new(tool) : tool] }
      end
    end
  end
end
