# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Calls its block every +interval+ seconds from a thread of its own
    # until stopped. The thread connects as the starting thread did, to the
    # same roles and shards, and each beat checks out a connection from the
    # pool of each of +models+ and returns it, so the thread holds none
    # between beats.
    class ClaimHeartbeat # :nodoc:
      def initialize(models, interval, &beat)
        @models = models
        @interval = interval
        @beat = beat
        @lock = Mutex.new
        @wake = ConditionVariable.new
        @stopped = false
        @thread = start(::ActiveRecord::Base.connected_to_stack.to_a)
      end

      def stop
        @lock.synchronize do
          @stopped = true
          @wake.signal
        end
        @thread.join
      end

      private

      def start(connected_to)
        thread = Thread.new do
          ::ActiveRecord::Base.connected_to_stack.concat(connected_to)
          beat until stopped_after_interval?
        end
        thread.name = 'ruby_llm claim heartbeat'
        thread.report_on_exception = false
        thread
      end

      def stopped_after_interval?
        @lock.synchronize do
          @wake.wait(@lock, @interval) unless @stopped
          @stopped
        end
      end

      def beat
        connected(@models.map(&:connection_pool).uniq) { @beat.call }
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not renew a chat's claims: #{e.class}: #{e.message}")
      end

      def connected(pools, &)
        return yield if pools.empty?

        pools.first.with_connection { connected(pools.drop(1), &) }
      end
    end
  end
end
