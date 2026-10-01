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

      # Builds outside the lock, so a slow build never stalls other threads or
      # fibers. When two callers race, the first connection stored wins.
      def fetch(settings)
        @lock.synchronize { touch(settings) } || store(settings, yield)
      end

      def clear
        @lock.synchronize { @connections.clear }
      end

      private

      def touch(settings)
        forget_inherited_connections
        connection = @connections.delete(settings)
        @connections[settings] = connection if connection
      end

      def store(settings, connection)
        @lock.synchronize do
          connection = touch(settings) || connection
          @connections[settings] = connection
          @connections.shift while @connections.size > @limit
          connection
        end
      end

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
