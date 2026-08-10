# frozen_string_literal: true

module RubyLLM
  # Concise console output, the way Active Record prints records. Including
  # classes declare what matters in +inspect_attributes+; #inspect shows
  # those on one line with long strings truncated, and pretty printing
  # follows #inspect so IRB stays readable. Inspection is a summary, not
  # the data: everything remains reachable through the readers
  # (+message.raw+, +embedding.vectors+, +chat.messages+).
  module Inspectable
    TRUNCATE_AT = 64 # :nodoc:

    # Returns a one-line summary of the object built from its
    # +inspect_attributes+, omitting empty ones and truncating long values.
    def inspect
      attributes = inspect_attributes
                   .reject { |_, value| value.nil? || (value.respond_to?(:empty?) && value.empty?) }
                   .map { |name, value| "#{name}: #{format_for_inspect(value)}" }
      return "#<#{self.class.name}>" if attributes.empty?

      "#<#{self.class.name} #{attributes.join(', ')}>"
    end

    def pretty_print(printer) # :nodoc:
      printer.text(inspect)
    end

    # Returns the stock Ruby dump with every instance variable, for when
    # the one-line summary is not enough.
    #
    #   message.full_inspect
    #
    def full_inspect
      Object.instance_method(:inspect).bind_call(self)
    end

    private

    def format_for_inspect(value)
      if value.is_a?(String) && value.length > TRUNCATE_AT
        "#{value[0, TRUNCATE_AT]}...".inspect
      else
        value.inspect
      end
    end
  end
end
