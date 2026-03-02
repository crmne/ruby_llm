# frozen_string_literal: true

module RubyLLM
  # Represents provider thinking output.
  class Thinking
    attr_reader :text, :signature

    def initialize(text: nil, signature: nil)
      @text = text
      @signature = signature
    end

    def self.build(text: nil, signature: nil)
      text = nil if text.is_a?(String) && text.empty?
      signature = nil if signature.is_a?(String) && signature.empty?

      return nil if text.nil? && signature.nil?

      new(text: text, signature: signature)
    end

    def pretty_print(printer)
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
    # Normalized config for thinking across providers.
    class Config
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
