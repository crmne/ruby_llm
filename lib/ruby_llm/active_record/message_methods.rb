# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/attachment_helpers'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # Maps an application-owned message record onto RubyLLM's public Message
    # API while keeping accounting and tool-call rows private to the gem.
    module MessageMethods
      extend ActiveSupport::Concern
      include PayloadHelpers
      include AttachmentHelpers

      def chat_association # :nodoc:
        send(chat_association_name)
      end

      # Converts this record to a RubyLLM::Message.
      def to_llm
        entries = ruby_llm_usage_entries
        RubyLLM::Message.new(
          role: role.to_sym,
          content: extract_content,
          attachments: extract_attachments,
          thinking: thinking,
          citations: citations,
          server_tool_calls: server_tool_calls,
          raw_content: optional_column(:raw_content),
          raw_reasoning: optional_column(:raw_reasoning),
          usage_entries: entries,
          tool_calls: tool_calls,
          tool_call_id: parent_tool_call&.id,
          finish_reason: optional_column(:finish_reason),
          model: entries.reverse.find(&:succeeded?)&.model,
          cache_until_here: cache_until_here?
        )
      end

      def ruby_llm_usage_entries # :nodoc:
        ruby_llm_usages.map(&:to_entry)
      end

      # Marks this message as an explicit prompt cache boundary and returns it.
      def cache_until_here
        update!(cache_until_here: true)
        self
      end

      # Whether this message is a prompt cache boundary.
      def cache_until_here?
        optional_column(:cache_until_here) || false
      end

      # The reasoning the model returned with this message, as a RubyLLM::Thinking, or +nil+.
      def thinking
        RubyLLM::Thinking.build(
          text: optional_column(:thinking_text),
          signature: optional_column(:thinking_signature)
        )
      end

      # The source citations attached to this message, as RubyLLM::Citation values.
      def citations
        Array(optional_column(:citations)).map { |citation| RubyLLM::Citation.from_h(citation) }
      end

      # The provider-executed tool steps behind this message, as RubyLLM::ServerToolCall values.
      def server_tool_calls
        Array(optional_column(:server_tool_calls)).map { |call| RubyLLM::ServerToolCall.from_h(call) }
      end

      # Token usage across every provider attempt that produced this message.
      def tokens
        RubyLLM::Tokens.aggregate(ruby_llm_usages.map(&:tokens))
      end

      # The priced cost of every attempt that produced this message, as a RubyLLM::Cost.
      def cost
        records = ruby_llm_usages.to_a
        RubyLLM::Cost.aggregate(records.map(&:cost), complete: records.all?(&:cost_available?))
      end

      # Provider tool calls as RubyLLM::ToolCall values keyed by call id.
      def tool_calls
        ruby_llm_tool_calls.to_h { |record| [record.tool_call_id, record.to_llm] }
      end

      # The tool call this message answers, as a RubyLLM::ToolCall, or +nil+.
      def parent_tool_call
        ruby_llm_parent_tool_call&.to_llm
      end

      # The message records answering this message's tool calls.
      def tool_results
        ruby_llm_tool_calls.filter_map(&:result)
      end

      # Whether this message carries tool calls.
      def tool_call?
        ruby_llm_tool_calls.any?
      end

      # Whether this message answers a tool call.
      def tool_result?
        ruby_llm_parent_tool_call.present?
      end

      # The view partial for this message, by role: +messages/user+, +messages/assistant+,
      # +messages/tool_calls+, or +messages/tool+.
      def to_partial_path
        partial_prefix = self.class.name.underscore.pluralize
        role_partial = if tool_call?
                         'tool_calls'
                       elsif role.to_s == 'tool'
                         'tool'
                       else
                         role.to_s.presence || 'assistant'
                       end
        "#{partial_prefix}/#{role_partial}"
      end

      # The error text a tool result carries, or +nil+ when the result is not an error.
      def tool_error_message
        payload_error_message(extract_content)
      end

      # Why the model stopped, as the Symbol RubyLLM::Message reports.
      def finish_reason
        optional_column(:finish_reason)&.to_sym
      end

      # Returns the message text parsed as JSON, for structured output
      # responses. Returns +nil+ when the message has no text.
      def parsed
        text = extract_content
        return if text.nil? || text.empty?

        JSON.parse(text)
      end

      private

      def optional_column(name)
        self[name] if has_attribute?(name)
      end

      def extract_content
        plain_text_content(content)
      end

      def extract_attachments
        action_text_attachments = action_text_attachment_sources(content)
        return [] unless content_attachments?(action_text_attachments)

        @_tempfiles = []
        collect_attachments(action_text_attachments)
      end
    end
  end
end
