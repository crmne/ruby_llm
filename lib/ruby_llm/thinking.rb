# frozen_string_literal: true

module RubyLLM
  # A Thinking holds the reasoning output a provider returned alongside a
  # response. Instances appear on Message#thinking, and on Chunk#thinking
  # while streaming, when the model exposes its thinking.
  #
  #   chat = RubyLLM.chat(model: 'claude-opus-5').with_thinking(display: :summarized)
  #   response = chat.ask "What is 15 * 23?"
  #   response.thinking&.text
  #   response.thinking&.signature
  #
  class Thinking
    include Inspectable

    # The reasoning text the provider returned, or +nil+.
    attr_reader :text

    # The provider's opaque signature or encrypted reasoning payload for the
    # thinking block, or +nil+. Shown as redacted in pretty-print output.
    attr_reader :signature

    def initialize(text: nil, signature: nil) # :nodoc:
      @text = text
      @signature = signature
    end

    def self.build(text: nil, signature: nil) # :nodoc:
      signature = nil if signature.is_a?(String) && signature.empty?
      text = nil if text.is_a?(String) && text.empty? && signature.nil?

      return nil if text.nil? && signature.nil?

      new(text: text, signature: signature)
    end

    def inspect_attributes # :nodoc:
      { text: text, signature: signature ? '[REDACTED]' : nil }
    end
  end

  class Thinking
    class Controls # :nodoc: all
      PREFERRED_EFFORTS = %w[medium low minimal high xhigh max].freeze

      def initialize(model)
        @model = model
      end

      def enable
        effort = default_effort
        return { effort: effort } if effort

        budget = explicit_budget
        return { budget: budget } if budget
        return { enabled: true } if model.reasoning_option(:toggle)

        effort = preferred_effort
        return { effort: effort } if effort

        budget = minimum_budget
        return { budget: budget } if budget

        :already_on if reasoning_model? && model.reasoning_options.empty?
      end

      def disable
        return { effort: :none } if model.reasoning_option_values(:effort).include?('none')

        budget = model.reasoning_option(:budget_tokens)
        return { budget: 0 } if budget && budget[:min].is_a?(Numeric) && budget[:min] <= 0

        { enabled: false } if model.reasoning_option(:toggle) || budget
      end

      private

      attr_reader :model

      def default_effort
        option = model.reasoning_option(:effort)
        return unless option&.key?(:default)

        default = option[:default].to_s
        default.to_sym unless default == 'none'
      end

      def preferred_effort
        PREFERRED_EFFORTS.find { |effort| model.reasoning_option_values(:effort).include?(effort) }&.to_sym
      end

      def explicit_budget
        default = model.reasoning_option(:budget_tokens)&.fetch(:default, nil)
        default if default.is_a?(Numeric) && default.positive?
      end

      def minimum_budget
        minimum = model.reasoning_option(:budget_tokens)&.fetch(:min, nil)
        return unless minimum.is_a?(Numeric)

        [minimum, 1].max
      end

      def reasoning_model?
        model.supports?(:reasoning) || model.metadata[:reasoning] || model.metadata['reasoning']
      end
    end

    class Config # :nodoc: all
      attr_reader :effort, :budget, :display, :enabled

      def self.default
        new(intent: :enable)
      end

      def self.disabled
        new(intent: :disable)
      end

      def initialize(effort: nil, budget: nil, display: nil, enabled: nil, intent: nil)
        @effort = effort&.to_sym
        @budget = budget
        @display = display&.to_sym
        @enabled = enabled
        @intent = intent
      end

      def enabled?
        !@intent.nil? || !enabled.nil? || !effort.nil? || !budget.nil? || !display.nil?
      end

      def disabled?
        enabled == false || effort == :none
      end

      def resolve(model)
        return self if @intent.nil?

        options = Controls.new(model).public_send(@intent)
        return nil if options == :already_on
        raise ArgumentError, resolution_error(model) unless options

        self.class.new(**options)
      end

      private

      def resolution_error(model)
        message = "RubyLLM does not know how to #{@intent} thinking for #{model.provider}/#{model.id}."
        return "#{message} Pass effort:, budget:, or display:." if @intent == :enable

        "#{message} The model registry has no off control."
      end
    end
  end
end
