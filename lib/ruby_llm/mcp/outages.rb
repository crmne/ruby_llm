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
        def tools(server)
          return [] if down?(server)

          server.tools
        rescue ConnectionError => e
          report(server, e) if record(server)
          []
        end

        def down?(server)
          return false if server.tools_listed?

          key = key(server)
          @lock.synchronize { (@retry_at[key] || 0) > monotonic_now }
        end

        def clear
          @lock.synchronize { @retry_at.clear }
        end

        private

        def report(server, error)
          RubyLLM.logger.warn("MCP server #{server.name} is unreachable, so its tools sit out: #{error.message}")
          RubyLLM.instrument('mcp_unreachable.ruby_llm', server: server.name, error: error.message)
        end

        # Returns whether this caller started the backoff.
        def record(server)
          key = key(server)
          @lock.synchronize do
            now = monotonic_now
            @retry_at.delete_if { |_key, retry_at| retry_at <= now }
            next false if @retry_at.key?(key)

            @retry_at[key] = now + BACKOFF
            true
          end
        end

        # Settings, not classes, since RubyLLM.mcp builds a class per call.
        # Settings that depend on runtime state can differ per object, so one
        # tenant's server never sidelines another's.
        def key(server)
          settings = server.class
          endpoint = [settings.url, *settings.command]
          settings.transport || !endpoint.compact.all?(String) ? server : endpoint
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
