# frozen_string_literal: true

module RubyLLM
  # The typed answers to a set of questions, with model identity and accounting.
  # Obtain one through RubyLLM.judge or Judge.judge.
  #
  #   judgment.urgent.probability
  #   judgment.department.choice
  #   judgment.frustration.score
  #
  # Named answers are available as readers. Use #[] or #fetch for dynamic
  # names or names that conflict with existing methods, such as #model.
  class Judgment
    include Enumerable
    include Support::Inspectable
    include Accounting::Usage::Result

    # Returns the answers keyed by their declared String or Symbol names.
    attr_reader :answers

    # Returns the actual model ID reported by the provider.
    attr_reader :model

    # Returns the original provider response.
    attr_reader :raw

    def initialize(answers:, model:, tokens: Tokens.new, raw: nil, model_info: nil) # :nodoc:
      @answers = answers.dup.freeze
      @answer_keys = answers.keys.to_h { |key| [key.to_s, key] }.freeze
      @model = model
      @tokens = tokens
      @raw = raw
      @model_info = model_info
    end

    # Returns the named answer, accepting a String or Symbol, or nil if absent.
    def [](name)
      answers[@answer_keys[name.to_s]]
    end

    # Returns the named answer or raises KeyError if it is absent.
    def fetch(name)
      answers.fetch(@answer_keys.fetch(name.to_s))
    end

    # Yields each question name and answer, or returns an Enumerator.
    def each(&)
      answers.each(&)
    end

    # Returns token usage across all provider attempts.
    def tokens
      ruby_llm_usage_entries.empty? ? @tokens : ruby_llm_usage_tokens
    end

    # Returns cost across all provider attempts, preserving unknown amounts.
    def cost
      return ruby_llm_usage_cost unless ruby_llm_usage_entries.empty?

      Cost.new(tokens:, model: @model_info)
    end

    # Returns the model, typed answers, token usage, and cost as a Hash.
    def to_h
      { model:, answers: answers.transform_values(&:to_h), tokens: tokens.to_h, cost: cost.to_h }
    end

    def inspect_attributes # :nodoc:
      { model:, answers: answers.keys }
    end

    def self.judge(input, questions:, with: nil, model: nil, provider: nil, context: nil, # :nodoc:
                   assume_model_exists: false, provider_options: {}, metadata: nil)
      config = context&.config || RubyLLM.config
      attachments = Attachment.wrap(with, config:)
      validate_input!(input, attachments)
      raise ArgumentError, 'A judgment requires a model' unless model || config.default_judgment_model

      model, provider_instance = Models.resolve(model, provider:, assume_model_exists:, config:, operation: :judge,
                                                       default_model: config.default_judgment_model)
      empty_tokens = Tokens.new
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.name,
        model: model.id,
        model_info: model,
        question_count: questions.size,
        attachment_count: attachments.size,
        provider_options:,
        metadata:,
        tokens: empty_tokens,
        cost: Cost.new(tokens: empty_tokens, model:)
      }

      RubyLLM.instrument('judgment.ruby_llm', payload, config:) do |event|
        result = provider_instance.judge(input, questions:, model:, with: attachments, provider_options:)
        event[:result] = result
        event[:tokens] = result.tokens
        event[:cost] = result.cost
        result
      end
    end

    def self.validate_input!(input, attachments)
      return if input.is_a?(String) || input.is_a?(Hash) || input.is_a?(Array) || (input.nil? && attachments.any?)

      raise ArgumentError, 'Judgment input must be text, a Hash, or an Array'
    end
    private_class_method :validate_input!

    private

    def method_missing(name, *args, &block)
      return super unless args.empty? && !block && @answer_keys&.key?(name.to_s)

      self[name]
    end

    def respond_to_missing?(name, include_private = nil)
      @answer_keys&.key?(name.to_s) || super
    end
  end
end
