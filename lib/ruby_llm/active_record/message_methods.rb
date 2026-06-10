# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/attachment_helpers'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # Methods mixed into message models.
    module MessageMethods
      extend ActiveSupport::Concern
      include PayloadHelpers
      include AttachmentHelpers

      def chat_association
        send(chat_association_name)
      end

      def tool_calls_association
        send(tool_calls_association_name)
      end

      def model_association
        send(model_association_name)
      end

      def to_llm
        RubyLLM::Message.new(
          role: role.to_sym,
          content: extract_content,
          thinking: thinking,
          tokens: tokens,
          tool_calls: extract_tool_calls,
          tool_call_id: extract_tool_call_id,
          model_id: model_association&.model_id
        )
      end

      def thinking
        RubyLLM::Thinking.build(
          text: optional_column(:thinking_text),
          signature: optional_column(:thinking_signature)
        )
      end

      def tokens
        RubyLLM::Tokens.build(
          input: input_tokens,
          output: output_tokens,
          cached: optional_column(:cached_tokens),
          cache_creation: optional_column(:cache_creation_tokens),
          thinking: optional_column(:thinking_tokens)
        )
      end

      def cost
        RubyLLM::Cost.new(tokens:, model: model_association)
      end

      def cache_read_tokens
        optional_column(:cached_tokens)
      end

      def cache_write_tokens
        optional_column(:cache_creation_tokens)
      end

      def to_partial_path
        partial_prefix = self.class.name.underscore.pluralize
        role_partial = if to_llm.tool_call?
                         'tool_calls'
                       elsif role.to_s == 'tool'
                         'tool'
                       else
                         role.to_s.presence || 'assistant'
                       end
        "#{partial_prefix}/#{role_partial}"
      end

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
        return RubyLLM::Content::Raw.new(content_raw) if has_attribute?(:content_raw) && content_raw.present?

        content_value = content
        content_value = content_value.to_plain_text if content_value.respond_to?(:to_plain_text)

        return content_value unless respond_to?(:attachments) && attachments.attached?

        RubyLLM::Content.new(content_value).tap do |content_obj|
          @_tempfiles = []

          attachment_sources.each do |attachment, attachable|
            add_attachment_to_content(content_obj, attachment, attachable)
          end
        end
      end
    end
  end
end
