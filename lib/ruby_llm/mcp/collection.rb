# frozen_string_literal: true

module RubyLLM
  class MCP
    # The MCP servers connected to a chat, readable by name.
    #
    #   chat.with_mcp(Linear.new(user: current_user))
    #   chat.mcp.linear     # => #<Linear ...>
    #   chat.mcp[:linear]   # => #<Linear ...>
    #   chat.mcp.map(&:name) # => ["linear"]
    #
    class Collection
      include Enumerable

      def initialize # :nodoc:
        @servers = {}
      end

      def <<(server) # :nodoc:
        @servers[server.name.to_sym] = server
        self
      end

      # Returns the server named +name+, or +nil+.
      def [](name)
        @servers[name.to_sym]
      end

      # Yields each server.
      def each(&)
        @servers.each_value(&)
      end

      # Returns whether no servers are connected.
      def empty?
        @servers.empty?
      end

      def inspect # :nodoc:
        "#<#{self.class.name} #{@servers.keys.join(', ')}>"
      end

      private

      def method_missing(name, *arguments)
        return super unless arguments.empty? && @servers.key?(name)

        @servers[name]
      end

      def respond_to_missing?(name, include_private = nil)
        @servers.key?(name) || super
      end
    end
  end
end
