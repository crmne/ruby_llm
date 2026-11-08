# frozen_string_literal: true

module RubyLLM
  class MCP
    # The servers that could not be reached lately, for this whole process.
    # A server waits this long, or as long as its Retry-After asks, before
    # anyone tries it again, since a server that never answers would
    # otherwise hold up every request, and each request in a job builds its
    # MCP objects anew. A server that answers that it is unavailable, with
    # HTTP 429 or a 5xx status, counts as one that can't be reached; one
    # that refuses the credentials or the request does not, since trying
    # again won't fix that.
    module Outages # :nodoc:
      BACKOFF = 60
      PARTLY_RUN = 'The call may have partly run, so check before trying it again.'

      # The tool error of a call the server failed, which a chat gives the
      # model like any tool error.
      class Failure < Hash # :nodoc:
      end
      UNAVAILABLE = [ConnectionError, RateLimitError, ServerError, ServiceUnavailableError, OverloadedError,
                     Stdio::Unavailable].freeze

      @lock = Mutex.new
      @retry_at = {}

      class << self
        def tools(server)
          return [] if down?(server)

          server.tools
        rescue RubyLLM::Error => e
          raise unless unavailable?(e)

          report(server, e) if record(server, backoff(e))
          []
        end

        # Yields to call one of +server+'s tools, and returns the tool error
        # when the server fails the call, or right away while the server
        # sits out. A handler declared on the server's class or on MCP::Tool
        # takes the error instead, but not one every Tool inherits, so a
        # catch-all on RubyLLM::Tool keeps the outage handling. Checking on
        # a task still raises, since the task may still be running.
        def calling(server, tool, input)
          return yield if input&.key?('task')
          return Failure[error: "The #{server.name} MCP server can't be reached right now"] if down?(server)

          begin
            yield
          rescue StandardError => e
            raise if server.class.rescue_handler_for(e) || tool.class.rescue_handler_for(e, within: MCP::Tool)

            failed_call(server, tool, e) || raise
          end
        end

        # Returns the tool error for a call +server+ failed, or +nil+ for an
        # error the call should raise: one that is not the server's, or a
        # refusal such as missing credentials or an unknown endpoint. A
        # server that is unavailable sits out until its backoff ends. The
        # model reads what the server wrote, even with redacted error
        # messages, since it is the one deciding what to do next.
        def failed_call(server, tool, error)
          return unless error.is_a?(Error) || (error.is_a?(RubyLLM::Error) && unavailable?(error))
          return if refused_status?(error.response&.status)

          if unavailable?(error)
            report(server, error) if record(server, backoff(error))
            server.send(:forget_tools)
          end
          Failure[error: failure_text(server, tool, error)]
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

        # Names the error by its class and status, since a connection
        # error's message can carry the server's host or URL.
        def report(server, error)
          status = error.response&.status
          RubyLLM.logger.warn("MCP server #{server.name} is unreachable, so its tools sit out: " \
                              "#{[error.class, ("HTTP #{status}" if status)].compact.join(', ')}")
          RubyLLM.instrument('mcp_unreachable.ruby_llm', { server: server.name, error: error.message },
                             config: server.send(:config))
        end

        def failure_text(server, tool, error)
          text = "The #{server.name} MCP server failed: #{error.provider_message || error.message}"
          partly_run?(tool, error) ? "#{text.delete_suffix('.')}. #{PARTLY_RUN}" : text
        end

        # A call that broke off, or that the server failed with a 5xx
        # status, may have done some of its work before it stopped, unless
        # the tool says it has no effect or the same call again has none.
        def partly_run?(tool, error)
          return false if tool.read_only? || (tool.idempotent? && !tool.destructive?)

          unavailable?(error) && error.response&.status != 429
        end

        def unavailable?(error)
          UNAVAILABLE.any? { |kind| error.is_a?(kind) } || unavailable_status?(error.response&.status)
        end

        def refused_status?(status)
          (400..499).cover?(status) && !unavailable_status?(status)
        end

        def unavailable_status?(status)
          status == 429 || (500..599).cover?(status)
        end

        def backoff(error)
          value = error.response&.headers&.[]('Retry-After').to_s
          seconds = Float(value, exception: false) || seconds_until(value)
          seconds&.positive? ? seconds : BACKOFF
        end

        def seconds_until(date)
          Time.httpdate(date) - Time.now
        rescue ArgumentError
          nil
        end

        # Returns whether this caller started the backoff.
        def record(server, backoff)
          key = key(server)
          @lock.synchronize do
            now = monotonic_now
            @retry_at.delete_if { |_key, retry_at| retry_at <= now }
            next false if @retry_at.key?(key)

            @retry_at[key] = now + backoff
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
