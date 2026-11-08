# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Calls its block every +interval+ seconds from a thread of its own
    # until stopped. The thread connects as the starting thread did, to the
    # same roles and shards, and each beat checks out a connection from the
    # pool of each of +models+ and returns it, so the thread holds none
    # between beats.
    #
    # A beat that fails is skipped, and the next one tries again. A lease
    # spans at least four intervals, so a claim outlasts a skipped beat,
    # but after two in a row it may lapse before the next one lands, so
    # the second logs a warning.
    class ClaimHeartbeat # :nodoc:
      def initialize(models, interval, &beat)
        @models = models
        @interval = interval
        @beat = beat
        @failed_beats = 0
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
        deadline = monotonic_now + (@interval / 4.0)
        connected(@models.map(&:connection_pool).uniq, deadline) { @beat.call }
        @failed_beats = 0
      rescue StandardError => e
        beat_failed(e)
      end

      def beat_failed(error)
        @failed_beats += 1
        if @failed_beats == 1 && busy?(error)
          RubyLLM.logger.debug("RubyLLM skipped renewing a chat's claims, the database was busy")
        else
          RubyLLM.logger.warn("RubyLLM could not renew a chat's claims (#{@failed_beats} in a row): " \
                              "#{error.class}: #{error.message}")
        end
      end

      def busy?(error)
        error.cause.is_a?(::SQLite3::BusyException) if defined?(::SQLite3::BusyException)
      end

      def connected(pools, deadline, &)
        return yield if pools.empty?

        pools.first.with_connection do |connection|
          waiting_until(connection, deadline) { connected(pools.drop(1), deadline, &) }
        end
      end

      # Before Rails 8, SQLite waits for a lock through busy_timeout, which
      # holds the GVL and stops every thread in the process, including the
      # run whose transaction holds the lock. The beat waits with the GVL
      # released instead, until its deadline, and then disconnects, so the
      # next query on that connection reconnects with the application's own
      # busy settings.
      def waiting_until(connection, deadline)
        return yield unless gvl_held_while_busy?(connection)

        begin
          connection.raw_connection.busy_handler { monotonic_now < deadline && sleep(0.001) }
          yield
        ensure
          connection.disconnect!
        end
      end

      def gvl_held_while_busy?(connection)
        connection.adapter_name == 'SQLite' && ::ActiveRecord::VERSION::MAJOR < 8
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
