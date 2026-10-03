# frozen_string_literal: true

module RubyLLM
  # One criterion's verdict or native decision, with its acceptance policy.
  class EvaluationResult
    include Support::Inspectable

    # Returns the criterion name.
    attr_reader :name
    # Returns a boolean, Probability, Score, or Choice without discarding its distribution.
    attr_reader :value
    # Returns the evaluator's explanation, when available.
    attr_reader :reason
    # Returns the exception when this criterion could not be evaluated.
    attr_reader :error
    # Returns the actual evaluator model identifier, when available.
    attr_reader :model
    # Returns the evaluator conversation or native judgment, as frozen portable evidence.
    attr_reader :evidence

    def initialize(name:, value: nil, reason: nil, minimum: nil, error: nil, model: nil, evidence: nil) # :nodoc:
      if !minimum.nil? && !value.is_a?(Probability) && !value.is_a?(Score)
        raise ArgumentError, 'Minimum applies only to a probability or score'
      end

      @name = name.to_sym
      @value = value
      @reason = reason
      @minimum = minimum
      @error = error
      @model = model
      @evidence = evidence
      freeze
    end

    # Returns true when this criterion passed its acceptance policy.
    def passed?
      status == :passed
    end

    def decision # :nodoc:
      return if error
      return value if [true, false].include?(value)
      return if @minimum.nil?

      number = case value
               when Probability then value.probability
               when Score then value.score
               end
      number >= @minimum unless number.nil?
    end

    # Returns :passed, :failed, :measured, :unassessed, or :error.
    def status
      return :error if error
      return :unassessed if value.nil?
      return :measured if decision.nil?

      decision ? :passed : :failed
    end

    # Returns the measurement, policy, and outcome as a Hash.
    def to_h
      { name:, status:, value: value.respond_to?(:to_h) ? value.to_h : value,
        reason:, minimum: @minimum, model:, evidence:,
        error: error && { class: error.class.name, message: error.message } }
    end

    def inspect_attributes # :nodoc:
      { name:, status: }
    end
  end
end
