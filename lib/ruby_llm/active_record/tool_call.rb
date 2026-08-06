# frozen_string_literal: true

require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # RubyLLM's private persistence for provider tool calls.
    class ToolCall < ::ActiveRecord::Base # :nodoc:
      self.table_name = 'ruby_llm_tool_calls'

      include PayloadHelpers

      belongs_to :message, polymorphic: true
      belongs_to :result, polymorphic: true, optional: true

      validates :tool_call_id, :name, presence: true

      def to_llm
        RubyLLM::ToolCall.new(
          id: tool_call_id,
          name: name,
          arguments: arguments || {},
          thought_signature: thought_signature
        )
      end

      def tool_error_message
        payload_error_message(arguments)
      end
    end
  end
end
