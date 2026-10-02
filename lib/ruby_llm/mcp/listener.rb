# frozen_string_literal: true

module RubyLLM
  class MCP
    # Keeps a subscription to a server's changes open in a thread of its
    # own, so the notifications reach the MCP while chats and requests go
    # on. #start returns once the server acknowledges the subscription.
    # When a stream ends, the listener subscribes again after a delay that
    # starts at a second and doubles up to a minute, and gives up when the
    # server agrees to send nothing or does not know the method. Changes
    # made in between are lost, so once the server acknowledges again, the
    # +resumed+ callable receives what the listener listens to.
    #
    # Stopping raises CancelledError in the listener's thread. Callbacks run
    # with that deferred, so a stop never cuts one short, and inside the
    # Rails executor when Rails is loaded. The thread reports no progress
    # to a chat that started it. A forked child does not inherit the
    # thread, so it listens again only when started again.
    class Listener # :nodoc:
      RETRY_DELAY = 1
      MAX_RETRY_DELAY = 60
      STOP_TIMEOUT = 5

      def initialize(client, name:, timeout:, resumed: nil, &on_notification)
        @client = client
        @name = name
        @timeout = timeout
        @resumed = resumed
        @on_notification = on_notification
        @control = Mutex.new
        @lock = Mutex.new
        @acknowledged = ConditionVariable.new
      end

      # Listens for +changes+, a subscriptions/listen filter, instead of
      # whatever the listener heard before. Returns the changes the server
      # agreed to send, or +nil+ when there is nothing to listen for.
      def start(changes)
        @control.synchronize do
          next @state if running? && changes == @changes

          halt
          launch(changes) unless changes.empty?
        end
      end

      def stop
        @control.synchronize { halt }
      end

      private

      def running?
        @pid == Process.pid && @thread&.alive?
      end

      def launch(changes)
        @changes = changes
        @pid = Process.pid
        @state = nil
        @thread = Thread.new { Support::ProgressReporter.listen(nil) { run } }
        @thread.name = 'ruby_llm-mcp-listener'
        @thread.report_on_exception = false
        acknowledgment
      end

      def acknowledgment
        settled = settle_within(@timeout)
        return @state if @state.is_a?(Hash)

        halt
        raise @state if settled

        raise Error, "#{@name} did not acknowledge the subscription"
      end

      def settle_within(timeout)
        deadline = monotonic_now + timeout
        @lock.synchronize do
          until @state
            remaining = deadline - monotonic_now
            return false unless remaining.positive?

            @acknowledged.wait(@lock, remaining)
          end
          true
        end
      end

      def run
        delay = RETRY_DELAY
        loop do
          opened = monotonic_now
          ending = subscribe
          break unless again?(ending)

          delay = RETRY_DELAY if monotonic_now - opened >= MAX_RETRY_DELAY
          pause(delay * (1 + rand) / 2, ending)
          delay = [delay * 2, MAX_RETRY_DELAY].min
        end
      rescue CancelledError
        nil
      end

      def pause(seconds, ending)
        reason = ending ? "stopped sending changes: #{ending.message}" : 'ended the subscription'
        RubyLLM.logger.warn { "#{@name} #{reason}; listening again in #{seconds.round(1)}s" }
        sleep(seconds)
      end

      def subscribe
        @client.listen(@changes) { |notification| receive(notification) }
        nil
      rescue CancelledError
        raise
      rescue StandardError => e
        e
      end

      def receive(notification)
        acknowledged = notification['method'] == Client::ACKNOWLEDGED
        listened = notification.dig('params', 'notifications') || {}
        resumed = acknowledged && @resumed && @state.is_a?(Hash)
        Thread.handle_interrupt(CancelledError => :never) do
          dispatch(@on_notification, notification)
          dispatch(@resumed, listened) if resumed
        end
        settle(listened) if acknowledged
      end

      def dispatch(callback, argument)
        executor = defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.executor
        executor ? executor.wrap { callback.call(argument) } : callback.call(argument)
      rescue StandardError => e
        RubyLLM.logger.error { "#{@name} after_change callback failed: #{e.class}: #{e.message}" }
      end

      def again?(ending)
        unless @state.is_a?(Hash)
          settle(ending || Error.new("#{@name} ended the subscription before acknowledging it"))
          return false
        end

        !@state.empty? && !(ending.is_a?(Error) && ending.code == Client::METHOD_NOT_FOUND)
      end

      def settle(state)
        @lock.synchronize do
          @state = state
          @acknowledged.broadcast
        end
      end

      def halt
        thread = @thread
        @thread = nil
        return unless thread&.alive? && @pid == Process.pid

        thread.raise(CancelledError)
        thread.join(STOP_TIMEOUT) unless thread == Thread.current
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
