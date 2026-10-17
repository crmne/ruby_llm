# frozen_string_literal: true

require 'securerandom'
require 'digest'
require 'json'

module RubyLLM
  class Chat
    class ToolCallIds # :nodoc:
      def self.answer(result, messages)
        calls = unanswered(messages)
        call = calls.find { |candidate| candidate.id == result.tool_call_id } ||
               calls.reverse.find { |candidate| candidate.provider_call_id == result.tool_call_id }
        call ? result.with_tool_call_id(call.id) : result
      end

      def self.unanswered(messages)
        answered = messages.select(&:tool_result?).to_set(&:tool_call_id)
        messages.select(&:tool_call?).flat_map { |message| message.tool_calls.values }
                .reject { |call| answered.include?(call.id) }
      end
      private_class_method :unanswered

      def initialize(namespace: nil)
        @ids = {}
        @namespace = namespace
      end

      def assign(message)
        return message unless message.tool_call?

        calls = message.tool_calls.transform_values do |call|
          call.provider_call_id ? call.with_id(id_for(call.provider_call_id)) : call
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
