# frozen_string_literal: true

module RubyLLM
  class Evaluation
    class Runner # :nodoc:
      def initialize(instance, test_case, repetition, groups, run_id:)
        @instance = instance
        @test_case = test_case
        @repetition = repetition
        @groups = groups
        @run_id = run_id
        @evaluations = []
        @costs = []
      end

      def run
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @instance.prepare(@test_case)
        begin
          run_steps
        ensure
          teardown
        end
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        Trial.new(test_case: @test_case, repetition: @repetition, result: @instance.result,
                  output: @evidence&.output, evidence: @evidence&.data, evaluations: @evaluations,
                  assertion_count: @instance.assertion_context.assertions,
                  assertion_failure: @assertion_failure,
                  error: @error, duration:, task_cost: result_cost,
                  evaluator_cost: Cost.aggregate(@costs, complete: @evaluations.none?(&:error)))
      end

      private

      def run_steps
        metadata = { case: @test_case.name, repetition: @repetition }
        RubyLLM.workflow(@instance.class.name || 'Evaluation', id: @run_id, metadata:) do |workflow|
          workflow.step('perform') { perform }
          workflow.step('evaluate') { evaluate } if @evidence
        end
      end

      def perform
        @instance.setup
        @evidence = @instance.execute
        @instance.assertions
      rescue ::Minitest::Assertion => e
        @assertion_failure = e
      rescue StandardError => e
        @error = e
      end

      def evaluate
        data = @test_case.to_h.except(:name).merge(actual: @evidence.data)
        @groups.each do |backend, criteria|
          results, cost = backend.call(data, criteria, attachments: @evidence.attachments)
          @evaluations.concat(results)
          @costs << cost
        rescue StandardError => e
          @evaluations.concat(criteria.map { |criterion| Result.new(name: criterion[:name], error: e) })
          @costs << Cost.new(complete: false)
        end
      end

      def teardown
        @instance.teardown
      rescue StandardError => e
        @error ||= e
      end

      def result_cost
        @instance.result.cost if @instance.result.respond_to?(:cost)
      end
    end
  end
end
