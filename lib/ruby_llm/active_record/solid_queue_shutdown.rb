# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Solid Queue stops a worker on TERM and waits its shutdown timeout for
    # the jobs to finish. Then it ends the process with exit!, which runs no
    # ensure block, so a run still going can't expire its claims as it stops.
    # Once a process that ends that way starts stopping, its claims end by
    # the time it exits. A forked worker's process ends with the worker. In
    # async mode the workers are threads of the supervisor's process, which
    # ends when the supervisor stops, while a worker the supervisor replaces
    # leaves the process running.
    module SolidQueueShutdown # :nodoc:
      module_function

      def install(solid_queue)
        solid_queue.on_worker_stop { |worker| exiting(solid_queue) if forked?(worker) }
        solid_queue.on_stop { |supervisor| exiting(solid_queue) if supervisor.try(:mode).to_s == 'async' }
      end

      def forked?(worker)
        supervisor = worker.supervisor
        !supervisor.nil? && supervisor.pid != ::Process.pid
      end

      def exiting(solid_queue)
        require 'ruby_llm/active_record/claim_heartbeat'
        require 'ruby_llm/active_record/run_claims'
        RunClaims.process_exits_by(Time.current + solid_queue.shutdown_timeout)
      end
    end
  end
end
