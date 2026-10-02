# frozen_string_literal: true

module RubyLLM
  # Defines reusable probability, choice, and score questions over application data.
  #
  #   class TicketTriage < RubyLLM::Judge
  #     probability :urgent, "Does this need attention today?"
  #     choice :department, "Which team should handle this?" do
  #       billing "Payments and refunds"
  #       technical "Bugs and integrations"
  #     end
  #   end
  #
  #   TicketTriage.judge("Please refund my duplicate charge today.").urgent.probability
  #
  # Uses Configuration#default_judgment_model unless a model is declared or
  # supplied for the call. An isolated context supplies its own default.
  #
  # Blocks and procs resolve once per judgment, with declared inputs available
  # as methods. Hashes and arrays preserve structured instructions and criteria.
  class Judge
    class << self
      def inherited(subclass) # :nodoc:
        super
        subclass.instance_variable_set(:@model_options, model.dup)
        subclass.instance_variable_set(:@input_names, inputs.dup)
        subclass.instance_variable_set(:@question_definitions, question_definitions.dup)
        subclass.instance_variable_set(:@provider_options, provider_options)
      end

      # Sets the model and provider used by this judge. A block or proc resolves
      # the model using runtime inputs. With no arguments, returns the settings.
      # Without a declaration, uses Configuration#default_judgment_model.
      def model(value = nil, **options, &block)
        return @model_options || {} if value.nil? && options.empty? && !block

        raise ArgumentError, 'Pass a model or a block, not both' if !value.nil? && block

        @model_options = options.merge(model: block || value).freeze
      end

      # Declares required runtime inputs available in question and data blocks.
      # With no arguments, returns the declared names.
      #
      #   inputs :teams
      #   choice :department, "Which team?", -> { teams.to_h { |team| [team.slug, team.description] } }
      def inputs(*names)
        return @input_names || [] if names.empty?

        @input_names = names.flatten.map(&:to_sym).freeze
      end

      # Sets provider-specific request options as a Hash, proc, or block.
      # With no arguments, returns the declared options.
      def provider_options(value = nil, &block)
        return @provider_options || {} if value.nil? && !block

        raise ArgumentError, 'Pass provider options or a block, not both' if !value.nil? && block

        @provider_options = Data.copy(block || value)
      end

      # Declares a yes/no question whose answer is the probability of yes.
      # Optional criteria describe +yes+ and +no+ in a Hash, proc, or block.
      #
      #   probability :urgent, "Does this need attention today?" do
      #     yes "An explicit deadline today"
      #     no "No deadline or a later deadline"
      #   end
      def probability(name, instructions = nil, criteria = nil, &)
        declare_question(name, :probability, instructions, criteria, &)
      end

      # Declares a question selecting one named option. Options are a Hash,
      # a proc returning a Hash, or a block declaring named descriptions.
      #
      #   choice :department, "Which team?" do
      #     billing "Payments and refunds"
      #     other nil
      #   end
      def choice(name, instructions = nil, options = nil, &)
        declare_question(name, :choice, instructions, options, &)
      end

      # Declares a question scored against ordered levels. Levels are an Array
      # or a proc or block returning one. Scores can fall between level indexes.
      #
      #   score :frustration, "How frustrated is the customer?", ["Calm", "Frustrated", "Angry"]
      def score(name, instructions = nil, levels = nil, &)
        declare_question(name, :score, instructions, levels, &)
      end

      # Judges text, a Hash, an Array, or images passed as +with:+ and returns
      # a Judgment. A block or proc can supply the input. Declared inputs are
      # accepted as keyword arguments; remaining options are forwarded to #judge.
      #
      #   TicketTriage.judge do
      #     message "Please refund the duplicate charge today."
      #   end
      def judge(input = nil, **options, &)
        values = options.slice(*inputs)
        new(**values).judge(input, **options.except(*inputs), &)
      end

      def question_definitions # :nodoc:
        @question_definitions ||= {}
      end

      private

      def declare_question(name, type, instructions, criteria, &)
        question = Question.new(name, type:, instructions:, criteria:, &)
        @declared_names ||= []
        raise ArgumentError, "Duplicate question: #{name}" if @declared_names.include?(name.to_s)

        @declared_names << name.to_s
        question_definitions[name.to_s] = question
        self
      end
    end

    # Creates a judge with the runtime inputs declared by its class.
    def initialize(**inputs)
      missing = self.class.inputs - inputs.keys
      extra = inputs.keys - self.class.inputs
      raise ArgumentError, "Missing judge inputs: #{missing.join(', ')}" unless missing.empty?
      raise ArgumentError, "Unknown judge inputs: #{extra.join(', ')}" unless extra.empty?

      inputs.each do |name, value|
        raise ArgumentError, "Judge input conflicts with a method: #{name}" if respond_to?(name, true)

        define_singleton_method(name) { value }
      end
    end

    # Judges the supplied input and returns a Judgment. Accepts model and
    # provider overrides, images as +with:+, an isolated +context:+,
    # +provider_options:+, and instrumentation +metadata:+. Additional
    # +questions:+ are a Hash keyed by question name, with +type:+,
    # +instructions:+, and +criteria:+ (probability), +options:+ (choice), or
    # +levels:+ (score). The block supplies input only. Input may be omitted
    # when images are supplied.
    #
    #   RubyLLM.judge("Please help today",
    #     questions: { urgent: { type: :probability, instructions: "Is this urgent?" } })
    #   Receipt.judge(with: "receipt.png")
    def judge(input = nil, questions: {}, with: nil, context: nil, metadata: nil, **options, &block)
      raise ArgumentError, 'Pass judgment input or a block, not both' if !input.nil? && block

      data = resolve_data(block || input)
      definitions = resolve_questions(questions)
      settings = self.class.model.merge(provider_options: self.class.provider_options).merge(options)
      settings = settings.transform_values { |value| resolve_data(value) }
      Judgment.judge(data, questions: definitions, with:, context:, metadata:, **settings)
    end

    private

    def resolve_data(value)
      Data.copy(value) { |callable| Builder.resolve(callable, scope: self) }
    end

    def resolve_questions(questions)
      questions = resolve_data(questions)
      raise ArgumentError, 'Questions must be a Hash' unless questions.is_a?(Hash)

      definitions = self.class.question_definitions.dup
      questions.each do |name, definition|
        raise ArgumentError, "Duplicate question: #{name}" if definitions.key?(name.to_s)

        definitions[name.to_s] = Question.from_h(name, definition)
      end
      raise ArgumentError, 'A judgment needs at least one question' if definitions.empty?

      definitions.transform_values { |definition| definition.resolve(self) }
    end
  end
end
