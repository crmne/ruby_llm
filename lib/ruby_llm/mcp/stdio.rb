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
    # The process inherits only INHERITED_ENV from the application, and +env+
    # adds to and overrides those: a Hash, or a callable that returns one,
    # called each time the process starts. Where the platform has process
    # groups the server leads its own, so stopping it reaches the processes
    # it started.
    #
    # Subscriptions share the channel, so whichever thread reads a message
    # that belongs to one hands it to the subscription's listener: a
    # request waiting for its answer, or the listener itself while no
    # request reads. A listener stops when CancelledError is raised in its
    # thread, so it reads and writes with that deferred.
    class Stdio # :nodoc:
      SHUTDOWN_GRACE = 2
      SHUTDOWN_CHECK = 0.05
      CHECK_INTERVAL = 0.5
      SUBSCRIPTION_ID = 'io.modelcontextprotocol/subscriptionId'
      INHERITED_ENV = %w[
        GEM_HOME GEM_PATH HOME LANG LC_ALL LC_CTYPE LOGNAME PATH SHELL TERM TMPDIR USER
        APPDATA COMSPEC HOMEDRIVE HOMEPATH LOCALAPPDATA PATHEXT PROCESSOR_ARCHITECTURE
        PROGRAMDATA PROGRAMFILES PROGRAMFILES(X86) PROGRAMW6432 SYSTEMDRIVE SYSTEMROOT
        TEMP TMP USERNAME USERPROFILE WINDIR
      ].freeze

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

      # The session of a server that predates 2026-07-28: the process it was initialized in, or +nil+.
      attr_reader :session

      def initialize(command, env: {}, directory: nil, timeout: nil, config: RubyLLM.config)
        @command = Array(command).map(&:to_s)
        @env = env
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
      ensure
        uninterrupted { @lock.synchronize { @subscriptions.delete(subscription) } }
      end

      def close
        @lock.synchronize { stop }
      end

      private

      def check_session(version)
        return if version.nil? || version == Client::VERSION || (@process&.alive? && @process.equal?(@session))

        raise SessionExpired.new("#{name} exited", session: @session)
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
      rescue IOError
        raise Error, "#{name} exited"
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
        begin
          @stdin.puts JSON.generate(message)
          @stdin.flush
        rescue Errno::EPIPE, IOError
          stop
          raise Error, "#{name} exited"
        end
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
        options[:pgroup] = true if groups?
        env = ENV.slice(*INHERITED_ENV).merge(environment)
        @stdin, @stdout, @process = Open3.popen2(env, *@command, unsetenv_others: true, **options)
        @buffer = +''
      end

      def environment
        variables = @env.respond_to?(:call) ? @env.call : @env
        variables.to_h { |key, value| [key.to_s, value.to_s] }
      end

      def stop
        return unless @process

        @stdin.close unless @stdin.closed?
        @stdout.close unless @stdout.closed?
        @process.join(SHUTDOWN_GRACE)
        terminate if groups? || @process.alive?
        @process = nil
      end

      def terminate
        signal('TERM')
        signal('KILL') unless exited?
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      def exited?
        deadline = monotonic_now + SHUTDOWN_GRACE
        while monotonic_now < deadline
          signal(0)
          sleep SHUTDOWN_CHECK
        end
        false
      rescue Errno::ESRCH, Errno::EPERM
        true
      end

      def signal(signal)
        Process.kill(signal, groups? ? -@process.pid : @process.pid)
      end

      def groups?
        !Gem.win_platform?
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
