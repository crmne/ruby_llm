# frozen_string_literal: true

module RubyLLM
  class Evaluation
    # A run's trials and summary. Persist with #save for review and comparisons.
    class Report
      include Enumerable
      include Support::Inspectable

      # Returns the evaluation class name.
      attr_reader :name
      # Returns the unique run identifier.
      attr_reader :id
      # Returns the trials in dataset and repetition order.
      attr_reader :trials
      # Returns the UTC time the run started.
      attr_reader :started_at
      # Returns the criterion definitions and evaluator identities captured for this run.
      attr_reader :definitions

      def initialize(name:, trials:, id:, started_at:, definitions:) # :nodoc:
        @name = name
        @trials = trials.freeze
        @id = id
        @started_at = started_at
        @definitions = Judge::Data.copy(definitions)
        freeze
      end

      # Yields each trial, or returns an Enumerator.
      def each(&)
        trials.each(&)
      end

      # Returns trial counts keyed by status.
      def counts
        totals = trials.map(&:status).tally
        %i[passed failed measured unassessed error].to_h { |status| [status, totals.fetch(status, 0)] }
      end

      # Returns the passing fraction of all trials, including errors and ungraded measurements.
      def pass_rate
        trials.empty? ? nil : counts[:passed].fdiv(trials.size)
      end

      # Returns true only when the run is nonempty and every trial passed.
      def passed?
        trials.any? && trials.all?(&:passed?)
      end

      # Returns all trial evidence, measurements, and run identity as a Hash.
      def to_h
        { id:, name:, started_at: started_at.iso8601, definitions:, counts:, pass_rate:, trials: trials.map(&:to_h) }
      end

      # Writes a JSON report and returns the supplied path.
      def save(path)
        File.write(path, JSON.pretty_generate(to_h))
        path
      end

      # Returns a readable per-case report followed by counts.
      def to_s
        rows = trials.map { |trial| trial_description(trial) }
        [name, *rows, counts.map { |status, count| "#{count} #{status}" }.join(', ')].join("\n")
      end

      def inspect_attributes # :nodoc:
        { name:, trials: trials.size, **counts }
      end

      private

      def trial_description(trial)
        details = trial.evaluations.map { |item| "#{item.name}=#{item.status}" }.join(', ')
        heading = "#{trial.test_case.name} [#{trial.repetition}]: #{trial.status}"
        heading += " (#{details})" unless details.empty?
        [heading, *failure_messages(trial).map { |failure| "  #{failure}" }].join("\n")
      end

      def failure_messages(trial)
        messages = [trial.error&.message, trial.assertion_failure&.message]
        messages.concat(trial.evaluations.reject(&:passed?).map do |item|
          "#{item.name}: #{item.error&.message || item.reason || item.value.inspect}"
        end)
        messages.compact
      end
    end
  end
end
