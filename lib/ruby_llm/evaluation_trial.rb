# frozen_string_literal: true

module RubyLLM
  # The recorded outcome of one case and repetition, including failed attempts.
  class EvaluationTrial
    include Support::Inspectable

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
    # Returns each criterion's EvaluationResult.
    attr_reader :evaluations
    # Returns the number of Ruby assertions attempted.
    attr_reader :assertion_count
    # Returns an assertion failure, or nil.
    attr_reader :assertion_failure
    # Returns an execution or evidence-conversion error, or nil.
    attr_reader :error
    # Returns elapsed wall-clock seconds, including evaluators.
    attr_reader :duration
    # Returns the cost exposed by the task's returned result. Unknown costs remain unknown.
    attr_reader :task_cost
    # Returns the combined cost of evaluator responses.
    attr_reader :evaluator_cost

    def initialize(test_case:, repetition:, **attributes) # :nodoc:
      @test_case = test_case
      @repetition = repetition
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
      @evaluations = Array(@evaluations).freeze
      freeze
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
        task_cost: task_cost&.to_h, evaluator_cost: evaluator_cost&.to_h }
    end

    def inspect_attributes # :nodoc:
      { case: test_case.name, repetition:, status: }
    end
  end
end
