# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/attachment_helpers'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # MessageMethods is mixed into models that call
    # <tt>acts_as_message</tt>. It converts persisted records into
    # RubyLLM::Message objects and adds token, cost, prompt-caching, and
    # rendering helpers.
    #
    #   message = chat_record.messages.last
    #   message.tokens.input
    #   message.cost.total
    #   message.cache_until_here!
    module MessageMethods
      extend ActiveSupport::Concern
      include PayloadHelpers
      include AttachmentHelpers

      def chat_association # :nodoc:
        send(chat_association_name)
      end

      def tool_calls_association # :nodoc:
        send(tool_calls_association_name)
      end

      def model_association # :nodoc:
        send(model_association_name)
      end

      # Converts this record to a RubyLLM::Message, rebuilding the role,
      # content, attachments, thinking, citations, tokens, tool calls, and
      # prompt-cache flag from the persisted columns.
      def to_llm
        RubyLLM::Message.new(
          role: role.to_sym,
          content: extract_content,
          attachments: extract_attachments,
          thinking: thinking,
          citations: citations,
          tokens: tokens,
          tool_calls: extract_tool_calls,
          tool_call_id: extract_tool_call_id,
          finish_reason: optional_column(:finish_reason),
          model: model_association&.model_id,
          cache_until_here: cache_until_here?
        )
      end

      # Marks this message as a prompt-cache boundary and persists the flag.
      # Providers may then cache the conversation up to and including this
      # message. Returns +self+.
      #
      #   chat.add_message(role: :user, content: long_context).cache_until_here!
      #   chat.messages.last.cache_until_here!
      #
      def cache_until_here!
        update!(cache_until_here: true)
        self
      end

      # Returns whether this message is marked as a prompt-cache boundary.
      # Reads the optional +cache_until_here+ column.
      def cache_until_here?
        optional_column(:cache_until_here) || false
      end

      # Returns the persisted reasoning as a RubyLLM::Thinking, or +nil+
      # when the thinking columns are empty.
      def thinking
        RubyLLM::Thinking.build(
          text: optional_column(:thinking_text),
          signature: optional_column(:thinking_signature)
        )
      end

      # Returns the persisted citations as an array of RubyLLM::Citation
      # objects. Empty when the message has none.
      def citations
        Array(optional_column(:citations)).map { |citation| RubyLLM::Citation.from_h(citation) }
      end

      # Returns the persisted token counts as a RubyLLM::Tokens, or +nil+
      # when no counts were recorded.
      #
      #   message.tokens.input
      #   message.tokens.cache_read
      #
      def tokens
        RubyLLM::Tokens.build(
          input: input_tokens,
          output: output_tokens,
          cache_read: optional_column(:cache_read_tokens),
          cache_write: optional_column(:cache_write_tokens),
          thinking: optional_column(:thinking_tokens)
        )
      end

      # Returns a RubyLLM::Cost for this message. When the +cost_details+
      # column recorded a breakdown at completion, returns that frozen cost so
      # a later Models.refresh! does not rewrite it. Otherwise prices this
      # message's tokens against the associated model record's current pricing.
      #
      #   message.cost.total
      #
      def cost
        details = optional_column(:cost_details)
        return RubyLLM::Cost.from_h(details) if details.present?

        RubyLLM::Cost.new(tokens:, model: model_association)
      end

      # Returns the number of tokens served from the provider's prompt
      # cache. Reads the +cache_read_tokens+ column.
      def cache_read_tokens
        optional_column(:cache_read_tokens)
      end

      # Returns the number of tokens written to the provider's prompt
      # cache. Reads the +cache_write_tokens+ column.
      def cache_write_tokens
        optional_column(:cache_write_tokens)
      end

      # Returns whether this message recorded tool calls for the model to run.
      # Answered from the associations, without building a RubyLLM::Message.
      def tool_call?
        tool_calls_association.any?
      end

      # Returns whether this message is a tool result answering an earlier
      # tool call. Answered from the associations, without building a
      # RubyLLM::Message.
      def tool_result?
        parent_tool_call.present?
      end

      # Returns the partial path Rails uses to render this message. The
      # prefix comes from the model class name. The suffix is the role,
      # with +tool_calls+ for assistant messages that invoke tools and
      # +tool+ for tool results.
      #
      #   render @chat.messages
      #   # renders messages/_user, messages/_assistant, messages/_tool_calls, ...
      #
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

      # Returns the error message when this tool result recorded an error,
      # +nil+ otherwise.
      def tool_error_message
        payload_error_message(content)
      end

      private

      def optional_column(name)
        self[name] if has_attribute?(name)
      end

      def extract_tool_calls
        tool_calls_association.to_h do |tool_call|
          [
            tool_call.tool_call_id,
            RubyLLM::ToolCall.new(
              id: tool_call.tool_call_id,
              name: tool_call.name,
              arguments: tool_call.arguments,
              thought_signature: tool_call.try(:thought_signature)
            )
          ]
        end
      end

      def extract_tool_call_id
        parent_tool_call&.tool_call_id
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
