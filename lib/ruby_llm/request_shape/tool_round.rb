# frozen_string_literal: true

module RubyLLM
  class RequestShape
    # A ToolRound describes a model turn that called tools and the results
    # the request sends back before the next model turn: how many of each,
    # and whether they pair up the way the provider matches them.
    #
    #   round.turn    # => 1
    #   round.calls   # => 2
    #   round.results # => 1
    #   round.paired? # => false
    #   round.to_s    # => "tool round at #1: 2 calls, 1 result, not paired"
    #
    class ToolRound
      include Support::Inspectable

      # The index of the turn that made the calls.
      attr_reader :turn

      # The number of tool calls in the round.
      attr_reader :calls

      # The number of tool results sent back for the round.
      attr_reader :results

      # Creates a round at +turn+ with the number of +calls+ and +results+,
      # and whether they are +paired+.
      def initialize(turn:, calls:, results:, paired:)
        @turn = turn
        @calls = calls
        @results = results
        @paired = paired
      end

      # Returns whether every call has its result, matched the way the
      # provider matches them: by call id, or by position and tool name.
      def paired?
        @paired
      end

      # Returns the round in words.
      def to_s
        "tool round at ##{turn}: #{counted(calls, 'call')}, #{counted(results, 'result')}, " \
          "#{paired? ? 'paired' : 'not paired'}"
      end

      # Returns the round as a Hash with its turn, counts, and pairing.
      def to_h
        { turn: turn, calls: calls, results: results, paired: paired? }
      end

      def inspect_attributes # :nodoc:
        to_h
      end

      private

      def counted(count, noun)
        "#{count} #{noun}#{'s' unless count == 1}"
      end
    end
  end
end
