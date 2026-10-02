# frozen_string_literal: true

require 'io/wait'
require 'open3'

module RubyLLM
  class MCP
    # stdio. The server is a child process that reads one JSON-RPC message
    # per line on stdin and writes one per line on stdout. Reads never block
    # past the deadline, even on a partial line. It starts on the
    # first request, restarts after it exits, and handles one request at a
    # time. Its stderr is the parent's. A server that predates 2026-07-28
    # keeps its session for the life of its process, so after a restart its
    # requests raise SessionExpired until the client initializes it again.
    #
    # Subscriptions share the channel, so whichever thread reads a message
    # that belongs to one hands it to the subscription's listener: a
    # request waiting for its answer, or the listener itself while no
    # request reads. A listener stops when CancelledError is raised in its
    # thread, so it reads and writes with that deferred.
    class Stdio # :nodoc:
      SHUTDOWN_GRACE = 2
      CHECK_INTERVAL = 0.5
      SUBSCRIPTION_ID = 'io.modelcontextprotocol/subscriptionId'

      # The messages of the subscription opened by request +id+, or with no
      # +id+, the changes a server that predates subscriptions announces.
      Subscription = Struct.new(:id, :messages) do
        def claims?(message)
          return !message.key?('id') && Client::CHANGES.include?(message['method']) if id.nil?

          params = message['params'].is_a?(Hash) ? message['params'] : {}
          params.dig('_meta', SUBSCRIPTION_ID) == id || answer?(message) ||
            (message['method'] == 'notifications/cancelled' && params['requestId'] == id)
        end

        def answer?(message)
          !id.nil? && message['id'] == id && !message.key?('method')
        end
      end

      def initialize(command, env: {}, directory: nil, timeout: nil, config: RubyLLM.config)
        @command = Array(command).map(&:to_s)
        @env = env.to_h { |key, value| [key.to_s, value.to_s] }
        @directory = directory&.to_s
        @timeout = timeout || config.request_timeout
        @lock = Mutex.new
        @subscriptions = []
      end

      def request(message, version: nil, timeout: nil, **, &)
        @lock.synchronize do
          check_session(version)
          write(message)
          @session = @process if message[:method] == 'initialize'
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

      def listen(message, **)
        subscription = Subscription.new(message&.dig(:id), Queue.new)
        process = uninterrupted { @lock.synchronize { subscribe(subscription, message) } }
        loop do
          until subscription.messages.empty?
            reply = subscription.messages.pop
            return reply if subscription.answer?(reply)

            yield reply
          end
          raise Error, "#{name} exited" unless @process.equal?(process)

          receive(subscription)
        end
      rescue IOError
        raise Error, "#{name} exited"
      ensure
        uninterrupted { @lock.synchronize { @subscriptions.delete(subscription) } }
      end

      def close
        @lock.synchronize { stop }
      end

      private

      def check_session(version)
        return if version.nil? || version == Client::VERSION || (@process&.alive? && @process.equal?(@session))

        raise SessionExpired, "#{name} exited"
      end

      def subscribe(subscription, message)
        raise Error, "#{name} exited" unless message || @process&.alive?

        @subscriptions << subscription
        write(message) if message
        @process
      end

      def receive(subscription)
        read = uninterrupted do
          next false unless @lock.try_lock

          begin
            drain
          ensure
            @lock.unlock
          end
          true
        end
        return sleep(CHECK_INTERVAL) unless read

        @stdout.wait_readable(CHECK_INTERVAL) if subscription.messages.empty?
      end

      def drain
        loop do
          while (line = @buffer.slice!(/\A[^\n]*\n/))
            message = parse(line)
            handled?(message) if message
          end
          chunk = @stdout.read_nonblock(65_536, exception: false)
          return if chunk == :wait_readable

          exited unless chunk
          @buffer << chunk
        end
      end

      def handled?(message)
        return true if route(message)
        return false unless message.key?('method') && message.key?('id')

        answer(message)
        true
      end

      def route(message)
        @subscriptions.find { |subscription| subscription.claims?(message) }&.messages&.push(message)
      end

      def uninterrupted(&)
        Thread.handle_interrupt(CancelledError => :never, &)
      end

      def await(id, timeout)
        deadline = monotonic_now + timeout
        loop do
          reply = read(deadline)
          return reply if reply['id'] == id && !reply.key?('method')

          yield reply if !handled?(reply) && reply.key?('method') && block_given?
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
          message = parse(next_line(deadline))
          return message if message
        end
      end

      def parse(line)
        return if line.strip.empty?

        message = JSON.parse(line)
        message if message.is_a?(Hash)
      rescue JSON::ParserError
        RubyLLM.logger.debug { "#{name} wrote a line that is not JSON" }
        nil
      end

      def next_line(deadline)
        loop do
          line = @buffer.slice!(/\A[^\n]*\n/)
          return line if line

          remaining = deadline - monotonic_now
          raise Error, "#{name} did not answer in time" unless remaining.positive?

          Support::Cancellation.check
          next unless @stdout.wait_readable([remaining, CHECK_INTERVAL].min)

          chunk = @stdout.read_nonblock(65_536, exception: false)
          next if chunk == :wait_readable

          exited unless chunk
          @buffer << chunk
        end
      end

      def exited
        stop
        raise Error, "#{name} exited"
      end

      def answer(request)
        write(Client.reply(request))
      end

      def start
        options = @directory ? { chdir: @directory } : {}
        @stdin, @stdout, @process = Open3.popen2(@env, *@command, **options)
        @buffer = +''
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
