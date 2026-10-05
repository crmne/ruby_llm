# frozen_string_literal: true

module RubyLLM
  class Evaluation
    # The recorded outcome of one case and repetition, including failed attempts.
    class Trial
      include Support::Inspectable
      include Accounting::Usage::Result

      # Returns the case whose inputs were executed.
      attr_reader :test_case
      # Returns the one-based repetition number.
      attr_reader :repetition
      # Returns the original value returned by perform, when it completed.
      attr_reader :result
      # Returns the primary output extracted from the returned value.
      attr_reader :output
      # Returns the frozen evidence supplied to evaluators.
      attr_reader :evidence
      # Returns each criterion's Evaluation::Result.
      attr_reader :evaluations
      # Returns the number of Ruby assertions attempted.
      attr_reader :assertion_count
      # Returns an assertion failure, or nil.
      attr_reader :assertion_failure
      # Returns an execution or evidence-conversion error, or nil.
      attr_reader :error
      # Returns elapsed wall-clock seconds, including evaluators.
      attr_reader :duration

      def initialize(test_case:, repetition:, task_usage: [], evaluator_usage: [], **attributes) # :nodoc:
        @test_case = test_case
        @repetition = repetition
        @task_usage = task_usage.freeze
        @evaluator_usage = evaluator_usage.freeze
        @ruby_llm_usage_entries = (task_usage + evaluator_usage).freeze
        attributes.each { |key, value| instance_variable_set("@#{key}", value) }
        @evaluations = Array(@evaluations).freeze
        freeze
      end

      # Returns a Tokens aggregate for every provider attempt made during this trial.
      def tokens
        ruby_llm_usage_tokens
      end

      # Returns a Cost aggregate for this trial, including task and evaluator requests.
      def cost
        ruby_llm_usage_cost
      end

      # Returns the task's tokens, including setup, assertions, and teardown requests.
      def task_tokens
        Tokens.aggregate(@task_usage.map(&:tokens))
      end

      # Returns the tokens used by the evaluators and their tools.
      def evaluator_tokens
        Tokens.aggregate(@evaluator_usage.map(&:tokens))
      end

      # Returns the task's cost, including setup, assertions, and teardown requests.
      def task_cost
        Cost.aggregate(@task_usage.map(&:cost), complete: @task_usage.all?(&:cost_available?))
      end

      # Returns the cost of the evaluators and their tools.
      def evaluator_cost
        Cost.aggregate(@evaluator_usage.map(&:cost), complete: @evaluator_usage.all?(&:cost_available?))
      end

      # Returns :passed, :failed, :measured, :unassessed, or :error. Empty trials are never passes.
      def status
        statuses = evaluations.map(&:status)
        statuses << :error if error
        statuses << :failed if assertion_failure
        statuses << :measured if evaluations.empty? && assertion_count.to_i.zero?
        %i[error failed unassessed measured].find { |status| statuses.include?(status) } || :passed
      end

      # Returns whether every assessment passed and no error occurred.
      def passed?
        status == :passed
      end

      # Returns the portable trial record, excluding the live application object.
      def to_h
        { case: test_case.to_h, repetition:, status:, evidence:, evaluations: evaluations.map(&:to_h),
          assertion_count:, assertion_failure: assertion_failure&.message, duration:,
          error: error && { class: error.class.name, message: error.message },
          tokens: tokens.to_h, cost: cost.to_h,
          task_tokens: task_tokens.to_h, evaluator_tokens: evaluator_tokens.to_h,
          task_cost: task_cost.to_h, evaluator_cost: evaluator_cost.to_h }
      end

      def inspect_attributes # :nodoc:
        { case: test_case.name, repetition:, status: }
      end
    end
  end
end
