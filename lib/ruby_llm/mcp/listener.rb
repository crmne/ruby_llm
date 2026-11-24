# frozen_string_literal: true

module RubyLLM
  class MCP
    # Keeps a subscription to a server's changes open. #start does so in a
    # thread of its own, so the notifications reach the MCP while chats and
    # requests go on, and returns once the server acknowledges the
    # subscription. #listen does so in the caller's thread or fiber, and
    # returns when the server ends the subscription for good.
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

      # Returns the subscriptions/listen filter for the lists a server with
      # +capabilities+ announces changes to, +resources+ as URIs or
      # MCP::Resource objects, and +tasks+ as MCP::Task objects or IDs.
      def self.filter(capabilities, resources, tasks)
        lists = %w[tools prompts resources].select { |list| capabilities.dig(list, 'listChanged') }
        lists.to_h { |list| [:"#{list}ListChanged", true] }
             .merge(resourceSubscriptions: named(resources, :uri), taskIds: named(tasks, :id))
             .reject { |_change, listened| listened == [] }
      end

      def self.named(items, reader)
        items.map { |item| item.respond_to?(reader) ? item.public_send(reader) : item.to_s }
      end

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
      # Raises Error when the server will not send updates for a resource
      # or task among them.
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

      # Listens for +changes+ where it is called, until the server agrees
      # to send nothing or does not know the method. Raises as #start
      # does, and what kept the server from acknowledging. Nothing but the
      # caller can interrupt its wait, so unlike #start it waits for the
      # acknowledgment as long as the transport does.
      def listen(changes)
        prepare(changes)
        begin
          cycle
        rescue CancelledError
          raise unless @state.is_a?(Exception)
        end
        raise @state if @state.is_a?(Exception)
      end

      private

      def running?
        @pid == Process.pid && @thread&.alive?
      end

      def prepare(changes)
        @changes = changes
        @state = nil
      end

      def launch(changes)
        prepare(changes)
        @pid = Process.pid
        @thread = Thread.new do
          Support::Cancellation.watch(nil) do
            Support::Instrumentation.with_workflow(nil) do
              Support::ProgressReporter.listen(nil) { Accounting::Usage.with_owner(nil) { run } }
            end
          end
        end
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
        cycle
      rescue CancelledError
        nil
      end

      def cycle
        delay = RETRY_DELAY
        loop do
          opened = monotonic_now
          ending = subscribe
          break unless again?(ending)

          delay = RETRY_DELAY if monotonic_now - opened >= MAX_RETRY_DELAY
          pause(delay * (1 + rand) / 2, ending)
          delay = [delay * 2, MAX_RETRY_DELAY].min
        end
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
        acknowledge(listened) if acknowledged
      end

      def acknowledge(listened)
        refusal = refuse(listened) unless @state.is_a?(Hash)
        settle(refusal || listened)
        raise CancelledError if refusal
      end

      def refuse(listened)
        missing = (Array(@changes[:resourceSubscriptions]) - Array(listened['resourceSubscriptions'])) +
                  (Array(@changes[:taskIds]) - Array(listened['taskIds']))
        Error.new("#{@name} does not send updates for #{missing.join(', ')}") unless missing.empty?
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
