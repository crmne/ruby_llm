# frozen_string_literal: true

require 'forwardable'

module RubyLLM
  # Defines reusable evaluations with a dataset, semantic criteria, and Ruby assertions.
  # Datasets default to app/evals/<class_name>.yml, .yaml, .json, or .jsonl.
  #
  #   class SupportEvaluation < RubyLLM::Evaluation
  #     evaluation :correctness, "The answer agrees with the expected output"
  #
  #     def perform(input)
  #       agent = SupportAgent.new
  #       agent.ask(input)
  #       agent
  #     end
  #
  #     def assertions
  #       assert output.length.positive?, "The answer must not be empty"
  #     end
  #   end
  #
  #   SupportEvaluation.run.save("tmp/support.json")
  class Evaluation
    extend Forwardable

    class << self
      def inherited(subclass) # :nodoc:
        super
        subclass.instance_variable_set(:@dataset, @dataset)
        subclass.instance_variable_set(:@evaluator, @evaluator)
        subclass.instance_variable_set(:@definitions, definitions.dup)
        subclass.instance_variable_set(:@adapters, adapters.dup)
      end

      # Sets the dataset path, enumerable of cases, or block returning cases.
      # With no argument, returns the configured source. The default is discovered by class name.
      def dataset(source = nil, &block)
        return @dataset if source.nil? && !block

        raise ArgumentError, 'Pass a dataset or a block, not both' if source && block

        @dataset = block || source
      end

      # Sets the default evaluator: a model, Agent class, or Judge class.
      # Model keywords accept provider, protocol, and context as Chat does.
      # Without a declaration, uses the default chat model and built-in reviewer.
      def evaluator(target = nil, **options)
        return @evaluator ||= Evaluator.new if target.nil? && options.empty?

        @evaluator = Evaluator.new(target, **options)
      end

      # Declares a semantic criterion. A minimum applies to a native probability or score;
      # without one, numeric decisions are measured but do not count as passes.
      # Omit instructions to set a minimum on a question already defined by a Judge.
      # Supply evaluator to override the class evaluator for this criterion.
      def evaluation(name, instructions = nil, minimum: nil, evaluator: nil)
        validate_criterion(name, minimum)
        name = name.to_sym
        @declared_names ||= []
        raise ArgumentError, "Duplicate evaluation: #{name}" if @declared_names.include?(name)

        @declared_names << name
        backend = Evaluator.new(evaluator) if evaluator
        definitions[name] = { name:, instructions: instructions&.dup&.freeze, minimum:, evaluator: backend }.freeze
      end

      # Converts a custom result into evaluation evidence. The original stays available as result.
      #
      #   adapt Invoice do |invoice|
      #     invoice.attributes.slice("total", "currency")
      #   end
      def adapt(type, &block)
        raise ArgumentError, 'An adapter needs a class and a block' unless type.is_a?(Module) && block

        adapters[type] = block
      end

      # Returns the dataset cases without running the application or its evaluators.
      # Supply only to select one or more case names, raising when any name is missing.
      def cases(dataset: nil, only: nil)
        loaded = Dataset.load(dataset || self.dataset, name: name)
        return loaded if only.nil?

        names = Array(only).map(&:to_s)
        missing = names - loaded.map(&:name)
        raise ArgumentError, "Unknown evaluation cases: #{missing.join(', ')}" if missing.any? || names.empty?

        loaded.select { |test_case| names.include?(test_case.name) }
      end

      # Executes fresh instances for every case and repetition and returns an Evaluation::Report.
      # A supplied dataset overrides discovery for this run. Configuration errors raise;
      # task, assertion, and evaluator failures are recorded per case.
      def run(dataset: nil, only: nil, repetitions: 1)
        validate_run(repetitions)
        cases = self.cases(dataset:, only:)
        groups = evaluation_groups
        definitions = Judge::Data.copy(groups.flat_map do |backend, criteria|
          criteria.map { |criterion| criterion.merge(evaluator: backend.description) }
        end)
        started_at = Time.now.utc
        id = SecureRandom.uuid
        trials = cases.flat_map do |test_case|
          Array.new(repetitions) do |index|
            new.run_case(test_case, index + 1, groups, run_id: id)
          end
        end
        Report.new(name: name || 'Anonymous evaluation', trials:, id:, started_at:, definitions:)
      end

      def definitions # :nodoc:
        @definitions ||= {}
      end

      def adapters # :nodoc:
        @adapters ||= {}
      end

      private

      def validate_run(repetitions)
        raise ArgumentError, 'Define perform(input) in your evaluation' if instance_method(:perform).owner == Evaluation
        return if repetitions.is_a?(Integer) && repetitions.positive?

        raise ArgumentError, 'Repetitions must be a positive Integer'
      end

      def validate_criterion(name, minimum)
        raise ArgumentError, 'An evaluation name cannot be empty' if name.to_s.empty?
        return if minimum.nil? || (minimum.is_a?(Numeric) && minimum.finite?)

        raise ArgumentError, 'Minimum must be a finite number'
      end

      def evaluation_groups
        all = evaluator.question_names.to_h do |name|
          [name, { name:, instructions: nil, minimum: nil }]
        end.merge(definitions)
        groups = all.values.group_by { |definition| definition[:evaluator] || evaluator }
        groups.each { |backend, criteria| criteria.each { |criterion| validate_instructions(backend, criterion) } }
        groups
      end

      def validate_instructions(backend, criterion)
        existing = backend.question_names.include?(criterion[:name])
        raise ArgumentError, "Duplicate Judge question: #{criterion[:name]}" if existing && criterion[:instructions]
        return if existing || !criterion[:instructions].to_s.empty?

        raise ArgumentError, "Missing instructions: #{criterion[:name]}"
      end
    end

    # Returns the current case's input, reference output, and metadata, respectively.
    attr_reader :input, :expected_output, :metadata
    # Returns the original value returned by perform.
    attr_reader :result

    # Runs the application under evaluation. Override in your evaluation class.
    def perform(_input)
      raise NotImplementedError, 'Define perform(input) in your evaluation'
    end

    # Runs Ruby assertions after perform. Override to use assert, refute, and the Minitest assertion family.
    def assertions; end

    # Runs before perform on each fresh case instance. Override for application fixtures.
    def setup; end

    # Runs after each case, even when setup, perform, or an assertion fails.
    def teardown; end

    # Returns the primary answer or value extracted from result.
    def output
      @evidence.output
    end

    # Returns retained messages from a Chat, Agent, or Message result.
    def messages
      @evidence.messages
    end

    # Returns tool calls recorded in the returned conversation or message.
    def tool_calls
      @evidence.tool_calls
    end

    # :method: assert
    # :call-seq:
    #   assert(condition, message = nil)
    #
    # Asserts that condition is truthy. Delegates to Minitest::Assertions and
    # records its assertion count. The other Minitest assert_* and refute_*
    # methods use the same contract. Call these from #assertions.

    # :method: refute
    # :call-seq:
    #   refute(condition, message = nil)
    #
    # Asserts that condition is false or nil. See #assert.

    # :method: assert_equal
    # :call-seq:
    #   assert_equal(expected, actual, message = nil)
    #
    # Asserts equality through Minitest::Assertions. See #assert.

    # :method: assert_includes
    # :call-seq:
    #   assert_includes(collection, value, message = nil)
    #
    # Asserts that the collection includes value. See #assert.

    # :stopdoc:
    def_delegators :assertion_context, *Assertions.instance_methods.grep(/\A(?:assert_|refute_|assert\z|refute\z)/)

    def run_case(test_case, repetition, groups, run_id:) # :nodoc:
      Runner.new(self, test_case, repetition, groups, run_id:).run
    end

    def prepare(test_case) # :nodoc:
      @input = JSON.parse(JSON.generate(test_case.inputs))
      @expected_output = test_case.expected_output
      @metadata = test_case.metadata
    end

    def execute # :nodoc:
      @result = perform(input)
      @evidence = Evidence.new(result, adapters: self.class.adapters)
    end

    def assertion_context # :nodoc:
      @assertion_context ||= Assertions.new
    end
    # :startdoc:
  end
end
