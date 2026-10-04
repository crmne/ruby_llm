# frozen_string_literal: true

module RubyLLM
  class Evaluation
    class Runner # :nodoc:
      USAGE_CONTEXT_KEY = :ruby_llm_evaluation_usage

      def initialize(instance, test_case, repetition, groups, run_id:)
        @instance = instance
        @test_case = test_case
        @repetition = repetition
        @groups = groups
        @run_id = run_id
        @evaluations = []
        @usage = { task: [], evaluator: [] }
        @mutex = Mutex.new
      end

      def run
        Support::Instrumentation.subscribe(self)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @instance.prepare(@test_case)
        with_usage(:task) do
          run_steps
        ensure
          teardown
        end
        @mutex.synchronize { @closed = true }
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        Trial.new(test_case: @test_case, repetition: @repetition, result: @instance.result,
                  output: @evidence&.output, evidence: @evidence&.data, evaluations: @evaluations,
                  assertion_count: @instance.assertion_count,
                  assertion_failure: @assertion_failure,
                  error: @error, duration:, task_usage: @usage[:task], evaluator_usage: @usage[:evaluator])
      ensure
        @mutex.synchronize { @closed = true }
        Support::Instrumentation.unsubscribe(self)
      end

      def instrument(name, payload)
        phase = Fiber[USAGE_CONTEXT_KEY]&.[](self)
        if name == 'usage.ruby_llm' && phase
          entry = Accounting::Usage::Entry.new(**payload.slice(:operation, :provider, :model, :status, :tokens, :cost))
          @mutex.synchronize { @usage[phase] << entry unless @closed }
        end
        yield if block_given?
      end

      private

      def run_steps
        metadata = { case: @test_case.name, repetition: @repetition }
        RubyLLM.workflow(@instance.class.name || 'Evaluation', id: @run_id, metadata:) do |workflow|
          workflow.step('perform') { perform }
          with_usage(:evaluator) { workflow.step('evaluate') { evaluate } } if @evidence
        end
      end

      def perform
        @instance.setup
        @evidence = @instance.execute
        @instance.assertions
      rescue Assertions::Failure => e
        @assertion_failure = e
      rescue StandardError => e
        @error = e
      end

      def evaluate
        data = @test_case.to_h.except(:name).merge(actual: @evidence.data)
        @groups.each do |backend, criteria|
          @evaluations.concat(backend.call(data, criteria, attachments: @evidence.attachments))
        rescue StandardError => e
          @evaluations.concat(criteria.map { |criterion| Result.new(name: criterion[:name], error: e) })
        end
      end

      def teardown
        @instance.teardown
      rescue StandardError => e
        @error ||= e
      end

      def with_usage(phase)
        previous = Fiber[USAGE_CONTEXT_KEY]
        Fiber[USAGE_CONTEXT_KEY] = (previous || {}).merge(self => phase)
        yield
      ensure
        Fiber[USAGE_CONTEXT_KEY] = previous
      end
    end
  end
end
