# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Methods mixed into message models.
    module MessageMethods
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :chat_class, :tool_call_class, :chat_foreign_key, :tool_call_foreign_key
      end

      def to_llm
        RubyLLM::Message.new(
          role: role.to_sym,
          content: extract_content,
          thinking: RubyLLM::Thinking.build(
            text: thinking_text_value,
            signature: thinking_signature_value
          ),
          tokens: tokens,
          tool_calls: extract_tool_calls,
          tool_call_id: extract_tool_call_id,
          model_id: model_association&.model_id
        )
      end

      def thinking
        RubyLLM::Thinking.build(
          text: thinking_text_value,
          signature: thinking_signature_value
        )
      end

      def tokens
        RubyLLM::Tokens.build(
          input: input_tokens,
          output: output_tokens,
          cached: cached_value,
          cache_creation: cache_creation_value,
          thinking: thinking_tokens_value
        )
      end

      private

      def thinking_text_value
        has_attribute?(:thinking_text) ? self[:thinking_text] : nil
      end

      def thinking_signature_value
        has_attribute?(:thinking_signature) ? self[:thinking_signature] : nil
      end

      def cached_value
        has_attribute?(:cached_tokens) ? self[:cached_tokens] : nil
      end

      def cache_creation_value
        has_attribute?(:cache_creation_tokens) ? self[:cache_creation_tokens] : nil
      end

      def thinking_tokens_value
        has_attribute?(:thinking_tokens) ? self[:thinking_tokens] : nil
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

        content_value = self[:content]

        return content_value unless respond_to?(:attachments) && attachments.attached?

        RubyLLM::Content.new(content_value).tap do |content_obj|
          @_tempfiles = []

          attachments.each do |attachment|
            tempfile = download_attachment(attachment)
            content_obj.add_attachment(tempfile, filename: attachment.filename.to_s)
          end
        end
      end

      def download_attachment(attachment)
        ext = File.extname(attachment.filename.to_s)
        basename = File.basename(attachment.filename.to_s, ext)
        tempfile = Tempfile.new([basename, ext])
        tempfile.binmode

        attachment.download { |chunk| tempfile.write(chunk) }

        tempfile.flush
        tempfile.rewind
        @_tempfiles << tempfile
        tempfile
      end
    end
  end
end
