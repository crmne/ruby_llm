# frozen_string_literal: true

module RubyLLM
  # A Thinking holds the reasoning output a provider returned alongside a
  # response. Instances appear on Message#thinking, and on Chunk#thinking
  # while streaming, when the model exposes its thinking.
  #
  #   chat = RubyLLM.chat(model: 'claude-opus-4.5').with_thinking(effort: :high)
  #   response = chat.ask "What is 15 * 23?"
  #   response.thinking&.text
  #   response.thinking&.signature
  #
  class Thinking
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
      text = nil if text.is_a?(String) && text.empty?
      signature = nil if signature.is_a?(String) && signature.empty?

      return nil if text.nil? && signature.nil?

      new(text: text, signature: signature)
    end

    def pretty_print(printer) # :nodoc:
      printer.object_group(self) do
        printer.breakable
        printer.text 'text='
        printer.pp text
        printer.comma_breakable
        printer.text 'signature='
        printer.pp(signature ? '[REDACTED]' : nil)
      end
    end
  end

  class Thinking
    class Config # :nodoc: all
      attr_reader :effort, :budget

      def initialize(effort: nil, budget: nil)
        @effort = effort.is_a?(Symbol) ? effort.to_s : effort
        @budget = budget
      end

      def enabled?
        !effort.nil? || !budget.nil?
      end
    end
  end
end
