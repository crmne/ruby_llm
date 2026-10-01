# frozen_string_literal: true

module RubyLLM
  module Support # :nodoc:
    class ProcessCache # :nodoc:
      LIMIT = 64

      def initialize(limit: LIMIT)
        @limit = limit
        @lock = Mutex.new
        @pid = Process.pid
        @entries = {}
      end

      # Builds outside the lock, so a slow build never stalls other threads or
      # fibers. When two callers race, the first value stored wins.
      def fetch(key)
        @lock.synchronize { touch(key) } || store(key, yield)
      end

      def clear
        @lock.synchronize { @entries.clear }
      end

      def delete(key)
        @lock.synchronize do
          forget_inherited_entries
          @entries.delete(key)
        end
      end

      private

      def touch(key)
        forget_inherited_entries
        value = @entries.delete(key)
        @entries[key] = value if value
      end

      def store(key, value)
        @lock.synchronize do
          value = touch(key) || value
          @entries[key] = value
          @entries.shift while @entries.size > @limit
          value
        end
      end

      # A forked child shares its parent's sockets and credentials. Closing
      # them here would tear down the parent's connections, so the child only
      # forgets them.
      def forget_inherited_entries
        return if @pid == Process.pid

        @pid = Process.pid
        @entries = {}
      end
    end
  end
end
