# frozen_string_literal: true

require 'securerandom'
require 'digest'
require 'json'

module RubyLLM
  class Chat
    class ToolCallIds # :nodoc:
      def initialize(namespace: nil)
        @ids = {}
        @namespace = namespace
      end

      def assign(message)
        return message unless message.tool_call?

        calls = message.tool_calls.transform_values do |call|
          call.id ? call.with_id(id_for(call.id)) : call
        end
        calls = ToolCall.index(calls.values) unless message.is_a?(Chunk)
        message.with_tool_calls(calls)
      end

      private

      def id_for(id)
        @ids[id] ||= @namespace ? Digest::SHA256.hexdigest(JSON.generate([*@namespace, id])) : SecureRandom.uuid
      end
    end
  end
end
