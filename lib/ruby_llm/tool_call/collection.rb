# frozen_string_literal: true

module RubyLLM
  class ToolCall
    # The tool calls of a Message: an Enumerable of ToolCall objects in the
    # order the provider returned them, also readable by call ID. Empty on
    # a message without calls.
    #
    #   response.tool_calls.first
    #   response.tool_calls.map(&:name) # => ["search_issues"]
    #   response.tool_calls["call_1"]
    #
    class Collection
      include Enumerable
      include Support::Inspectable

      def initialize(calls = {}) # :nodoc:
        @calls = calls.to_h
      end

      # Yields each ToolCall, in provider order.
      #
      #   response.tool_calls.each { |call| puts call.name }
      #
      def each(&)
        return enum_for(__method__) { size } unless block_given?

        @calls.each_value(&)
        self
      end
      alias each_value each

      # Returns the ToolCall with the ID +id+, or +nil+.
      def [](id)
        @calls[id]
      end

      def []=(id, call) # :nodoc:
        @calls[id] = call
      end

      # Returns the ToolCall with the ID +id+. Without a default or a block,
      # raises KeyError when there is none.
      def fetch(...)
        @calls.fetch(...)
      end

      # Returns the number of tool calls.
      def size
        @calls.size
      end
      alias length size

      # Returns +true+ when there are no tool calls.
      def empty?
        @calls.empty?
      end

      # Returns the tool calls as an Array.
      def values
        @calls.values
      end

      # Returns the call IDs as an Array.
      def keys
        @calls.keys
      end

      # Returns +true+ when there is a tool call with the ID +id+.
      def key?(id)
        @calls.key?(id)
      end

      # Returns a Hash of what the block returns for each ToolCall, keyed by
      # call ID.
      def transform_values(&)
        @calls.transform_values(&)
      end

      # Returns a Collection without the calls with the given IDs.
      def except(*ids)
        self.class.new(@calls.except(*ids))
      end

      # Returns the tool calls as a new Hash of ToolCall objects keyed by call
      # ID. With a block, returns the Hash of the pairs it makes from each ID
      # and ToolCall.
      def to_h(&block)
        block ? @calls.to_h(&block) : @calls.dup
      end
      alias to_hash to_h

      # Returns +true+ when +other+ is a Collection or Hash of the same calls
      # under the same IDs.
      def ==(other)
        other.respond_to?(:to_hash) && @calls == other.to_hash
      end

      # Returns the JSON of #to_h.
      def to_json(*)
        @calls.to_json(*)
      end

      # Returns the JSON-ready form of #to_h.
      def as_json(*)
        @calls.as_json(*)
      end

      private

      def inspect_attributes
        { calls: map(&:name) }
      end
    end
  end
end
