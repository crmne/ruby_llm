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
        @built = {}.compare_by_identity
      end

      def connect(server, chat) # :nodoc:
        server = server.new.tap { |built| @built[built] = chat } if server.is_a?(Class)
        replaced = self[server.name]
        release(replaced, chat) unless replaced.equal?(server)
        @servers[server.name.to_sym] = server
      end

      def disconnect(chat) # :nodoc:
        each { |server| release(server, chat) }
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

      def release(server, chat)
        server.close if @built[server].equal?(chat) && @built.delete(server)
      end

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
