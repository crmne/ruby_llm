# frozen_string_literal: true

require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # A tool call a message requested, in RubyLLM's +ruby_llm_tool_calls+
    # table. An assistant message reaches its calls through
    # +ruby_llm_tool_calls+, oldest first, and a tool message reaches the
    # call it answers through +ruby_llm_parent_tool_call+.
    #
    #   message.ruby_llm_tool_calls.pluck(:name) # => ["weather", "search"]
    #   RubyLLM::ActiveRecord::ToolCall.where(name: "weather").count
    #
    # Each row belongs to +message+, the assistant message that requested
    # it, and to +result+, the tool message that answers it once there is
    # one. Both associations are polymorphic. Its columns:
    #
    # [+tool_call_id+] The call's id, unique across the table.
    # [+name+] The tool's name.
    # [+namespace+] The namespace of a namespaced tool, or +nil+.
    # [+arguments+] The arguments the model passed, as a Hash. Empty when
    #               the model's text was not a JSON object.
    # [+approval+] <tt>"pending"</tt>, <tt>"approved"</tt>, <tt>"remembered"</tt>,
    #              or <tt>"denied"</tt>, or +nil+ when no approval was asked.
    # [+remote+] Whether the provider ran the tool instead of RubyLLM.
    #
    # RubyLLM writes these rows. Read and query them, and add scopes and
    # columns of your own, but do not create or update them.
    class ToolCall < Record
      self.table_name = 'ruby_llm_tool_calls'

      include PayloadHelpers

      belongs_to :message, polymorphic: true
      belongs_to :result, polymorphic: true, optional: true

      validates :tool_call_id, :name, presence: true

      # Returns this row as a RubyLLM::ToolCall.
      def to_llm
        RubyLLM::ToolCall.new(
          id: tool_call_id,
          provider_call_id: self[:provider_call_id],
          name: name,
          namespace: self[:namespace],
          arguments: arguments,
          malformed_arguments: malformed_arguments,
          thought_signature: thought_signature,
          remote: self[:remote]
        )
      end

      # Returns the arguments the model passed, as a Hash, or an empty Hash
      # when the model's text was not a JSON object.
      def arguments
        value = self[:arguments]
        value.is_a?(Hash) ? value : {}
      end

      def malformed_arguments # :nodoc:
        value = self[:arguments]
        value if value.is_a?(String)
      end

      # Returns whether a process is running this tool call: it has no
      # result yet and its claim has not expired.
      def running?
        (result_id.nil? && has_attribute?(:claimed_until) && claimed_until&.future?) || false
      end

      # Returns whether the call waits on a task or an MCP input request.
      def paused?
        has_attribute?(:mcp_state) && mcp_state.present?
      end

      def tool_error_message # :nodoc:
        payload_error_message(arguments)
      end
    end
  end
end
