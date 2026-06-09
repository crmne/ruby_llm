# frozen_string_literal: true

require 'active_support/core_ext/object/blank'
require 'tempfile'

module RubyLLM
  module ActiveRecord
    # Shared Active Storage handling for ActiveRecord-backed chats and
    # messages: writing RubyLLM attachments into Active Storage and
    # rebuilding RubyLLM::Content from stored attachments.
    module AttachmentHelpers
      private

      def persist_content(message_record, attachments)
        return unless message_record.respond_to?(:attachments)

        attachables = prepare_for_active_storage(attachments)
        message_record.attachments.attach(attachables) if attachables.any?
      end

      def prepare_for_active_storage(attachments)
        Utils.to_safe_array(attachments).filter_map do |attachment|
          case attachment
          when ActionDispatch::Http::UploadedFile, ActiveStorage::Blob
            attachment
          when ActiveStorage::Attachment, ActiveStorage::Attached::One, ActiveStorage::Attached::Many
            active_storage_blobs(attachment)
          when Hash
            attachment.values.map { |v| prepare_for_active_storage(v) }
          else
            convert_to_active_storage_format(attachment)
          end
        end.flatten.compact
      end

      def convert_to_active_storage_format(source)
        return if source.blank?

        attachment = source.is_a?(RubyLLM::Attachment) ? source : RubyLLM::Attachment.new(source)

        if attachment.active_storage?
          active_storage_blobs(attachment.source)
        else
          {
            io: StringIO.new(attachment.content),
            filename: attachment.filename,
            content_type: attachment.mime_type
          }
        end
      rescue StandardError => e
        RubyLLM.logger.warn "Failed to process attachment #{source}: #{e.message}"
        nil
      end

      def active_storage_blobs(attachment)
        case attachment
        when ActiveStorage::Blob then attachment
        when ActiveStorage::Attachment, ActiveStorage::Attached::One then attachment.blob
        when ActiveStorage::Attached::Many then attachment.blobs
        end
      end

      def build_content(message, attachments)
        return message if content_like?(message)

        RubyLLM::Content.new(message, attachments)
      end

      def content_like?(object)
        object.is_a?(RubyLLM::Content) || object.is_a?(RubyLLM::Content::Raw)
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
