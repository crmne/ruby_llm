# frozen_string_literal: true

module RubyLLM
  class MCP
    class OAuth
      # Keeps OAuth credentials in memory for the life of the process. Rails
      # applications keep them in the database instead.
      class MemoryStore # :nodoc:
        def initialize
          @credentials = {}
          @lock = Mutex.new
        end

        def read(key)
          @lock.synchronize { @credentials[key] }
        end

        def write(key, data, **)
          @lock.synchronize { @credentials[key] = data }
        end

        def delete(key)
          @lock.synchronize { @credentials.delete(key) }
        end
      end
    end
  end
end
