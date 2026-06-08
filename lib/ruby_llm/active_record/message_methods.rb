# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/payload_helpers'

module RubyLLM
  module ActiveRecord
    # Methods mixed into message models.
    module MessageMethods
      extend ActiveSupport::Concern
      include PayloadHelpers

      class_methods do
        attr_reader :chat_class, :tool_call_class, :chat_foreign_key, :tool_call_foreign_key
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

      def cost
        RubyLLM::Cost.new(tokens:, model: model_association)
      end

      def cache_read_tokens
        cached_value
      end

      def cache_write_tokens
        cache_creation_value
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

      def attachment_sources
        change = pending_attachment_change
        return attachments.map { |attachment| [attachment, nil] } unless pending_attachment_change?(change)

        change.attachments.zip(change.attachables)
      end

      def pending_attachment_change
        attachment_changes['attachments'] if respond_to?(:attachment_changes)
      end

      def pending_attachment_change?(change)
        change.respond_to?(:attachments) && change.respond_to?(:attachables)
      end

      def add_attachment_to_content(content_obj, attachment, attachable)
        if pending_upload_attachable?(attachable)
          add_pending_upload_attachment(content_obj, attachable)
        else
          tempfile = download_attachment(attachment)
          content_obj.add_attachment(tempfile, filename: attachment.filename.to_s)
        end
      end

      def pending_upload_attachable?(attachable)
        return false if attachable.nil? || attachable.is_a?(String)
        return false if instance_of_class?(attachable, 'ActiveStorage::Blob')

        uploaded_file?(attachable) || active_storage_upload_hash?(attachable) ||
          attachable.is_a?(File) || pathname?(attachable)
      end

      def uploaded_file?(attachable)
        instance_of_class?(attachable, 'ActionDispatch::Http::UploadedFile') ||
          instance_of_class?(attachable, 'Rack::Test::UploadedFile')
      end

      def active_storage_upload_hash?(attachable)
        attachable.is_a?(Hash) && attachment_hash_io(attachable).present?
      end

      def pathname?(attachable)
        defined?(Pathname) && attachable.is_a?(Pathname)
      end

      def add_pending_upload_attachment(content_obj, attachable)
        if attachable.is_a?(Hash)
          content_obj.add_attachment(attachment_hash_io(attachable), filename: attachment_hash_filename(attachable))
        else
          content_obj.add_attachment(attachable)
        end
      end

      def attachment_hash_io(attachable)
        attachable[:io] || attachable['io']
      end

      def attachment_hash_filename(attachable)
        filename = attachable[:filename] || attachable['filename']
        filename&.to_s
      end

      def instance_of_class?(object, class_name)
        Object.const_get(class_name).then { |klass| object.is_a?(klass) }
      rescue NameError
        false
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
