# frozen_string_literal: true

require 'io/wait'
require 'open3'

module RubyLLM
  class MCP
    # stdio. The server is a child process that reads one JSON-RPC message
    # per line on stdin and writes one per line on stdout. It starts on the
    # first request, restarts after it exits, and handles one request at a
    # time. Its stderr is the parent's.
    class Stdio # :nodoc:
      SHUTDOWN_GRACE = 2
      CHECK_INTERVAL = 0.5

      def initialize(command, env: {}, directory: nil, timeout: nil, config: RubyLLM.config)
        @command = Array(command).map(&:to_s)
        @env = env.to_h { |key, value| [key.to_s, value.to_s] }
        @directory = directory&.to_s
        @timeout = timeout || config.request_timeout
        @lock = Mutex.new
      end

      def request(message, timeout: nil, **, &)
        @lock.synchronize do
          write(message)
          await(message[:id], timeout || @timeout, &)
        end
      end

      def notify(message, **)
        @lock.synchronize { write(message) }
        nil
      end

      def cancel(notification, **)
        notify(notification)
      end

      def close
        @lock.synchronize { stop }
      end

      private

      def await(id, timeout)
        deadline = monotonic_now + timeout
        loop do
          reply = read(deadline)
          return reply if reply['id'] == id && !reply.key?('method')

          if reply.key?('method') && reply.key?('id')
            answer(reply)
          elsif reply.key?('method')
            yield reply if block_given?
          end
        end
      end

      def write(message)
        start unless @process&.alive?
        @stdin.puts JSON.generate(message)
        @stdin.flush
      rescue Errno::EPIPE, IOError
        stop
        raise Error, "#{name} exited"
      end

      def read(deadline)
        loop do
          remaining = deadline - monotonic_now
          raise Error, "#{name} did not answer in time" unless remaining.positive?

          Support::Cancellation.check
          next unless @stdout.wait_readable([remaining, CHECK_INTERVAL].min)

          line = @stdout.gets
          unless line
            stop
            raise Error, "#{name} exited"
          end
          next if line.strip.empty?

          return JSON.parse(line)
        rescue JSON::ParserError
          RubyLLM.logger.debug { "#{name} wrote a line that is not JSON" }
        end
      end

      def answer(request)
        reply = if request['method'] == 'ping'
                  { jsonrpc: '2.0', id: request['id'], result: {} }
                else
                  { jsonrpc: '2.0', id: request['id'], error: { code: -32_601, message: 'Method not found' } }
                end
        write(reply)
      end

      def start
        options = @directory ? { chdir: @directory } : {}
        @stdin, @stdout, @process = Open3.popen2(@env, *@command, **options)
      end

      def stop
        return unless @process

        @stdin.close unless @stdin.closed?
        @stdout.close unless @stdout.closed?
        terminate unless @process.join(SHUTDOWN_GRACE)
        @process = nil
      end

      def terminate
        Process.kill('TERM', @process.pid)
        Process.kill('KILL', @process.pid) unless @process.join(SHUTDOWN_GRACE)
      rescue Errno::ESRCH
        nil
      end

      def name
        File.basename(@command.first.to_s)
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
