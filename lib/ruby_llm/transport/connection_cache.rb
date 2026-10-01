# frozen_string_literal: true

module RubyLLM
  module Transport # :nodoc:
    class ConnectionCache # :nodoc:
      LIMIT = 64

      def initialize(limit: LIMIT)
        @limit = limit
        @lock = Mutex.new
        @pid = Process.pid
        @connections = {}
      end

      def fetch(settings)
        @lock.synchronize do
          forget_inherited_connections
          connection = @connections.delete(settings) || yield
          @connections[settings] = connection
          @connections.shift while @connections.size > @limit
          connection
        end
      end

      def clear
        @lock.synchronize { @connections.clear }
      end

      private

      # A forked child shares its parent's sockets. Closing them here would
      # tear down the parent's connections, so the child only forgets them.
      def forget_inherited_connections
        return if @pid == Process.pid

        @pid = Process.pid
        @connections = {}
      end
    end
  end
end
