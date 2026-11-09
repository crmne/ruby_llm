# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Providers
    class Moonshot
      # Kimi models cannot read a document attached to a message. Kimi
      # documents one way to ask about a file: extract its text through the
      # Files API and send that text in the conversation.
      # https://platform.kimi.ai/docs/guide/ask-questions-about-pdf-content
      module Documents
        EXTRACT_PURPOSE = 'file-extract'

        def preprocess_message(message, unsupported_attachment: nil)
          return super unless message.attachments.any? { |attachment| extracted_document?(attachment) }

          super(message.with_attachments(message.attachments.map do |attachment|
            extracted_document?(attachment) ? extracted_attachment(attachment) : attachment
          end), unsupported_attachment:)
        end

        # Kimi extracts a whole document without a model, so +model:+ only
        # labels the result. The upload exists only to read it back.
        def ocr(file, model:, pages: nil, provider_options: {})
          raise ArgumentError, "#{@provider.name} extracts whole documents; pages: is not available" if pages

          track_usage(:ocr) do
            upload = @provider.upload_file(file, purpose: EXTRACT_PURPOSE, provider_options:)
            begin
              text = @provider.download_file(upload.id)
              RubyLLM::OCR.new(pages: [{ 'index' => 0, 'markdown' => text }], model:, raw: upload.metadata)
            ensure
              delete_upload(upload)
            end
          end
        end

        private

        def provider_file_upload_options(_attachment)
          { purpose: EXTRACT_PURPOSE }
        end

        def extracted_document?(attachment)
          return attachment.source.purpose == EXTRACT_PURPOSE if attachment.provider_file?

          %i[pdf document].include?(attachment.type)
        end

        def extracted_attachment(attachment)
          filename = "#{File.basename(attachment.filename.to_s, '.*')}.md"
          Attachment.new(StringIO.new(extracted_text(attachment)), filename:, config: @config)
        end

        def extracted_text(attachment)
          return @provider.download_file(attachment.provider_file_id) if attachment.provider_file?

          download_upload(attachment)
        rescue Error => e
          message = Message.new(role: :user, content: nil, attachments: [attachment])
          raise if attachment.provider_file? || discard_missing_uploads([message], e).empty?

          download_upload(attachment)
        end

        def download_upload(attachment)
          @provider.download_file(provider_upload(attachment).id)
        end

        def delete_upload(upload)
          @connection.delete("files/#{upload.id}")
        rescue Error
          nil
        end
      end
    end
  end
end
