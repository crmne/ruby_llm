# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Shared helpers for converting persisted Active Record message content into RubyLLM content.
    module ContentExtraction
      private

      def plain_text_content(content_value)
        return content_value.to_plain_text if content_value.respond_to?(:to_plain_text)

        content_value
      end

      def action_text_attachment_sources(content_value)
        return [] unless content_value.respond_to?(:body)

        body = content_value.body
        return [] unless body.respond_to?(:attachables)

        body.attachables.filter_map { |attachable| active_storage_source_for(attachable) }.flatten
      end

      def active_storage_source_for(attachable)
        return unless defined?(::ActiveStorage)

        return attachable if active_storage_blob?(attachable)
        return attachable.blob if active_storage_attachment?(attachable)
        return attachable.blob if active_storage_attached_one?(attachable)
        return attachable.blobs if active_storage_attached_many?(attachable)

        attachable.blob if attachable.respond_to?(:blob)
      end

      def active_storage_blob?(source)
        defined?(::ActiveStorage::Blob) && source.is_a?(::ActiveStorage::Blob)
      end

      def active_storage_attachment?(source)
        defined?(::ActiveStorage::Attachment) && source.is_a?(::ActiveStorage::Attachment)
      end

      def active_storage_attached_one?(source)
        defined?(::ActiveStorage::Attached::One) && source.is_a?(::ActiveStorage::Attached::One)
      end

      def active_storage_attached_many?(source)
        defined?(::ActiveStorage::Attached::Many) && source.is_a?(::ActiveStorage::Attached::Many)
      end

      def add_action_text_attachments(content_obj, sources)
        sources.each do |source|
          content_obj.add_attachment(source, filename: active_storage_filename(source))
        end
      end

      def active_storage_filename(source)
        return source.filename.to_s if active_storage_blob?(source)
        return source.blob.filename.to_s if active_storage_attachment?(source)

        source.blob.filename.to_s if active_storage_attached_one?(source) && source.blob
      end
    end
  end
end
