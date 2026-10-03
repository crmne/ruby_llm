# frozen_string_literal: true

module RubyLLM
  class RequestShape
    # A Turn describes one entry of a request's conversation: a message, or
    # one item where the provider sends a model's reasoning and tool calls as
    # items of their own.
    #
    #   turn = error.request_shape.turns.last
    #   turn.index # => 4
    #   turn.role  # => "user"
    #   turn.to_s  # => "#4 user: text (31 chars)"
    #
    class Turn
      include Support::Inspectable

      # The turn's 0-indexed position in the request, the position a
      # provider's error message counts from.
      attr_reader :index

      # The turn's role as the payload names it, such as <tt>"model"</tt>,
      # or for an entry that names no role, its type, such as
      # <tt>"function_call"</tt>. Returns +nil+ when the entry names neither.
      attr_reader :role

      # The Part objects of the turn, in order.
      attr_reader :parts

      # Creates a turn at +index+ with +role+ and +parts+.
      def initialize(index:, role:, parts: [])
        @index = index
        @role = role
        @parts = parts
      end

      # Returns the turn as one line: its index, its role, and its parts.
      #
      #   turn.to_s # => "#3 model: thinking (11 chars), text (13 chars), signed"
      #
      def to_s
        "##{[index, role].compact.join(' ')}: #{parts.empty? ? 'no parts' : parts.join(', ')}"
      end

      # Returns the turn as a Hash with its index, role, and parts.
      def to_h
        { index: index, role: role, parts: parts.map(&:to_h) }
      end

      def inspect_attributes # :nodoc:
        { index: index, role: role, parts: parts.join(', ') }
      end
    end
  end
end
