# frozen_string_literal: true

module RubyLLM
  class MCP
    # The servers that could not be reached lately, for this whole process.
    # A server waits this long before anyone tries it again, since a server
    # that never answers would otherwise hold up every request, and each
    # request in a job builds its MCP objects anew.
    module Outages # :nodoc:
      BACKOFF = 60

      @lock = Mutex.new
      @retry_at = {}

      class << self
        # The tools a chat offers the model: the server's, or none while it
        # can't be reached.
        def tools(server)
          return [] if down?(server)

          server.tools
        rescue ConnectionError => e
          record(server)
          RubyLLM.logger.warn("MCP server #{server.name} is unreachable, so its tools sit out: #{e.message}")
          RubyLLM.instrument('mcp_unreachable.ruby_llm', server: server.name, error: e.message)
          []
        end

        def down?(server)
          key = key(server)
          @lock.synchronize do
            retry_at = @retry_at[key]
            next false unless retry_at
            next true if monotonic_now < retry_at

            @retry_at.delete(key)
            false
          end
        end

        def clear
          @lock.synchronize { @retry_at.clear }
        end

        private

        def record(server)
          @lock.synchronize { @retry_at[key(server)] = monotonic_now + BACKOFF }
        end

        # Settings, not classes, since RubyLLM.mcp builds a class per call.
        def key(server)
          settings = server.class
          [settings.url, settings.command, settings.transport]
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
