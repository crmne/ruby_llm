# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    module ChatSerialization # :nodoc:
      include Enumerable

      # Returns the record's JSON representation with the inherited serializer
      # and its options, rather than enumerating the conversation's messages.
      def as_json(options = nil)
        serializer = ChatSerialization.instance_method(:as_json).bind(self).super_method
        serializer = serializer.super_method while serializer.owner == Enumerable
        serializer.call(options)
      end
    end
  end
end
