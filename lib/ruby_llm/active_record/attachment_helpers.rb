# frozen_string_literal: true

require 'active_support/core_ext/object/blank'

module RubyLLM
  module ActiveRecord
    module AttachmentHelpers # :nodoc:
      private

      def persist_content(message_record, attachments)
        return unless message_record.respond_to?(:attachments)

        attachables = prepare_for_active_storage(attachments)
        return if attachables.empty?

        message_record.attachments.attach(attachables)
        Support::Utils.to_safe_array(attachments).grep(RubyLLM::Attachment).each do |attachment|
          attachment.provider_file_store ||= ProviderFile.store { persisted_blob_key(message_record, attachment) }
        end
      end

      # Active Storage records the size and MD5 of every blob, so the
      # message's blob of the same size holds the attachment's bytes. Only
      # attachments of equal size need the MD5 to tell them apart.
      def persisted_blob_key(message_record, attachment)
        blob = active_storage_blobs(attachment.source) if attachment.active_storage?
        return blob.key if blob.is_a?(ActiveStorage::Blob)

        content = attachment.content
        candidates = message_record.attachments.blobs.where(byte_size: content.bytesize).to_a
        return candidates.first&.key unless candidates.many?

        checksum = OpenSSL::Digest::MD5.base64digest(content)
        candidates.find { |candidate| candidate.checksum == checksum }&.key
      end

      def prepare_for_active_storage(attachments)
        Support::Utils.to_safe_array(attachments).filter_map do |attachment|
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
            content_type: attachment.mime_type,
            metadata: { resolution: attachment.resolution&.to_s }.compact
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

      def plain_text_content(content_value)
        return action_text_plain_text(content_value) if action_text_content?(content_value)
        return content_value.to_plain_text if content_value.respond_to?(:to_plain_text)

        content_value
      end

      def action_text_attachment_sources(content_value)
        return [] unless action_text_content?(content_value)

        action_text_attachables(content_value).flat_map do |attachable|
          action_text_attachable_sources(attachable)
        end.compact
      end

      def action_text_content?(content_value)
        content_value.respond_to?(:body) && action_text_body?(content_value.body)
      end

      def preload_action_text_embeds(messages)
        return unless defined?(ActionText::Attachment)

        rich_texts = messages.filter_map do |message|
          rich_text = message.rich_text_content
          body = rich_text&.body
          rich_text if action_text_body?(body) && action_text_embeds?(body)
        end
        return if rich_texts.empty?

        ::ActiveRecord::Associations::Preloader.new(
          records: rich_texts,
          associations: { embeds_attachments: :blob }
        ).call
      end

      def action_text_embeds?(body)
        body.fragment.find_all(ActionText::Attachment.tag_name).any? { |node| action_text_blob_id(node) }
      end

      def action_text_body?(body)
        defined?(ActionText::Attachment) && body.respond_to?(:fragment) && body.respond_to?(:attachables) &&
          body.respond_to?(:sanitize_content_attachment)
      end

      def action_text_plain_text(content_value)
        body = content_value.body
        preloaded_blobs = action_text_preloaded_blobs(content_value).index_by { |blob| blob.id.to_s }
        rendered = body.fragment.replace(ActionText::Attachment.tag_name) do |node|
          if node.key?('content')
            sanitized_content = body.sanitize_content_attachment(node.remove_attribute('content').to_s)
            node['content'] = sanitized_content if sanitized_content.present?
          end

          attachable = action_text_attachable_for_node(node, preloaded_blobs)
          ActionText::Attachment.from_node(node, attachable).to_plain_text
        end

        ActionText::Content.new(rendered, canonicalize: false).fragment.to_plain_text
      end

      def action_text_attachables(content_value)
        body = content_value.body
        preloaded_blobs = action_text_preloaded_blobs(content_value).index_by { |blob| blob.id.to_s }
        body.fragment.find_all(ActionText::Attachment.tag_name).map do |node|
          action_text_attachable_for_node(node, preloaded_blobs)
        end
      end

      def action_text_attachable_for_node(node, preloaded_blobs)
        preloaded_blobs[action_text_blob_id(node)] || ActionText::Attachable.from_node(node)
      end

      def action_text_blob_id(node)
        sgid = node['sgid']
        gid = SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME) if sgid
        return unless gid && gid.app == GlobalID.app && gid.model_name == ActiveStorage::Blob.name

        gid.model_id.to_s
      end

      def action_text_preloaded_blobs(content_value)
        return [] unless content_value.class.respond_to?(:reflect_on_association) &&
                         content_value.class.reflect_on_association(:embeds_attachments)

        association = content_value.association(:embeds_attachments)
        return [] unless association.loaded?

        content_value.embeds_attachments.filter_map do |attachment|
          blob_association = attachment.association(:blob)
          blob_association.target if blob_association.loaded?
        end
      end

      def action_text_attachable_sources(attachable)
        source = active_storage_blobs(attachable)
        source ||= attachable.blob if attachable.respond_to?(:blob)

        Support::Utils.to_safe_array(source)
      end

      def content_attachments?(action_text_attachments)
        action_text_attachments.any? || active_storage_attachments?
      end

      def active_storage_attachments?
        return false unless respond_to?(:attachments)

        preloaded = preloaded_attachments
        preloaded ? preloaded.any? : attachments.attached?
      end

      def preloaded_attachments
        return if pending_attachment_change || !self.class.reflect_on_association(:attachments_attachments)

        preloaded_records(:attachments_attachments)
      end

      # Building an association proxy evaluates the association's scope,
      # which costs more than reading the records a preload already loaded.
      def preloaded_records(name)
        association = association(name)
        association.target if association.loaded?
      end

      def collect_attachments(action_text_attachments)
        list = action_text_attachments.map { |source| RubyLLM::Attachment.new(source) }
        return list unless active_storage_attachments?

        list + attachment_sources.map { |attachment, attachable| stored_attachment(attachment, attachable) }
      end

      def attachment_sources
        change = pending_attachment_change
        return attachments_with_blobs.map { |attachment| [attachment, nil] } unless pending_attachment_change?(change)

        change.attachments.zip(change.attachables)
      end

      def attachments_with_blobs
        records = attachments.to_a
        ::ActiveRecord::Associations::Preloader.new(records: records, associations: :blob).call
        records
      end

      def pending_attachment_change
        attachment_changes['attachments'] if respond_to?(:attachment_changes)
      end

      def pending_attachment_change?(change)
        change.respond_to?(:attachments) && change.respond_to?(:attachables)
      end

      def stored_attachment(attachment, attachable)
        stored = if pending_upload_attachable?(attachable)
                   pending_upload_attachment(attachable)
                 else
                   RubyLLM::Attachment.new(attachment, resolution: attachment.metadata['resolution']&.to_sym)
                 end
        stored.provider_file_store = ProviderFile.store { attachment.blob&.key }
        stored
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

      def pending_upload_attachment(attachable)
        if attachable.is_a?(Hash)
          RubyLLM::Attachment.new(attachment_hash_io(attachable),
                                  filename: attachment_hash_filename(attachable),
                                  resolution: attachable.dig(:metadata, :resolution)&.to_sym)
        else
          RubyLLM::Attachment.new(attachable)
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
    end
  end
end
