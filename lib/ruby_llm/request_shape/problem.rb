# frozen_string_literal: true

module RubyLLM
  class RequestShape
    # A Problem is something in a request that providers are known to
    # reject, found by the protocol that rendered it: a part with no data, a
    # tool round whose calls and results do not pair up, a step that lacks
    # the signature the provider requires, or roles out of order.
    #
    #   problem.kind    # => :part_without_data
    #   problem.turn    # => 3
    #   problem.part    # => 0
    #   problem.to_s    # => "problem at #3, part 0: thinking part carries no data"
    #
    class Problem
      include Support::Inspectable

      # What is wrong: +:part_without_data+, +:empty_turn+,
      # +:unpaired_round+, +:unmatched_result+, +:unsigned_call+,
      # +:unsigned_thinking+, or +:role_order+.
      attr_reader :kind

      # The index of the turn the problem is in, or +nil+.
      attr_reader :turn

      # The position of the part in the turn's parts, or +nil+ when the
      # problem concerns the whole turn.
      attr_reader :part

      # The id of the call an unmatched tool result names, the only id a
      # shape shows, or +nil+.
      attr_reader :call_id

      # The problem in words.
      attr_reader :message

      # Creates a problem of +kind+ described by +message+.
      def initialize(kind:, message:, turn: nil, part: nil, call_id: nil)
        @kind = kind
        @message = message
        @turn = turn
        @part = part
        @call_id = call_id
      end

      # Returns the problem as one line, with where it is.
      def to_s
        location = ["##{turn}", part && "part #{part}"].compact.join(', ') if turn
        line = location ? "problem at #{location}: #{message}" : "problem: #{message}"
        call_id ? "#{line} (call id #{call_id})" : line
      end

      # Returns the problem as a Hash, omitting attributes it does not have.
      def to_h
        { kind: kind, turn: turn, part: part, call_id: call_id, message: message }.compact
      end

      def inspect_attributes # :nodoc:
        to_h
      end
    end
  end
end
