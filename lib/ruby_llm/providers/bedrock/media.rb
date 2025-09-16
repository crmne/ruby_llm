# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Media handling methods for the Bedrock API integration
      # NOTE: Bedrock does not support url attachments
      module Media
        extend Anthropic::Media

        module_function

        # Map MIME types / filenames to Bedrock's allowed document formats:
        # [docx, csv, html, txt, pdf, md, doc, xlsx, xls]
        MIME_TO_DOC_FORMAT = {
          'application/pdf' => 'pdf',
          'text/csv' => 'csv',
          'application/csv' => 'csv',
          'text/html' => 'html',
          'application/xhtml+xml' => 'html',
          'text/markdown' => 'md',
          'text/x-markdown' => 'md',
          'application/markdown' => 'md',
          'application/msword' => 'doc',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
          'application/vnd.ms-excel' => 'xls',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx'
        }.freeze

        EXT_TO_DOC_FORMAT = {
          'pdf' => 'pdf',
          'csv' => 'csv',
          'html' => 'html',
          'htm' => 'html',
          'md' => 'md',
          'markdown' => 'md',
          'doc' => 'doc',
          'docx' => 'docx',
          'xls' => 'xls',
          'xlsx' => 'xlsx'
        }.freeze

        # Bedrock Converse: filename sanitization for attachments
        # - Only alphanumeric characters, whitespace, hyphens, parentheses, and square brackets
        # - No more than one consecutive whitespace character
        def sanitize_filename(filename)
          return nil unless filename

          sanitized = filename.gsub(/[^a-zA-Z0-9\s\-()\[\]]/, '')
          sanitized = sanitized.gsub(/\s+/, ' ')
          sanitized = sanitized.strip
          sanitized.empty? ? nil : sanitized
        end

        def format_image(image)
          {
            'image' => {
              'format' => extract_image_format(image.mime_type),
              'name' => sanitize_filename(image.filename) || 'uploaded_image',
              'source' => { 'bytes' => image.encoded }
            }
          }
        end

        def format_document(document)
          {
            'document' => {
              'format' => extract_document_format(document),
              'name' => sanitize_filename(document.filename) || 'uploaded_document',
              'source' => { 'bytes' => document.encoded }
            }
          }
        end

        def format_text_file(text_file)
          {
            'document' => {
              'format' => extract_document_format(text_file),
              'name' => sanitize_filename(text_file.filename) || 'uploaded_text',
              'source' => { 'bytes' => text_file.encoded }
            }
          }
        end

        def format_text(text)
          {
            'text' => text.to_s
          }
        end

        def format_content(content)
          return [format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          attachments = content.attachments
          multiple_attachments = attachments.size > 1

          attachments.each_with_index do |attachment, index|
            part = build_part_for_converse(attachment)
            part = add_counter_prefix_if_needed(part, index, multiple_attachments)
            parts << part
          end

          parts
        end

        def build_part_for_converse(attachment)
          case attachment.type
          when :image
            format_image(attachment)
          when :pdf
            format_document(attachment)
          when :text
            format_text_file(attachment)
          else
            raise UnsupportedAttachmentError, attachment.type
          end
        end

        def add_counter_prefix_if_needed(part, index, enabled)
          return part unless enabled

          counter_prefix = "#{index + 1} "
          if part['image']
            part['image']['name'] = counter_prefix + part['image']['name'].to_s
          elsif part['document']
            part['document']['name'] = counter_prefix + part['document']['name'].to_s
          end
          part
        end

        def extract_image_format(mime_type)
          case mime_type
          when 'image/png'
            'png'
          when 'image/jpeg', 'image/jpg'
            'jpeg'
          when 'image/gif'
            'gif'
          when 'image/webp'
            'webp'
          else
            RubyLLM.logger.warn "Unknown image MIME type: #{mime_type}, defaulting to png"
            'png'
          end
        end

        def extract_document_format(attachment)
          mime = attachment.mime_type.to_s.downcase
          name = attachment.filename.to_s.downcase

          MIME_TO_DOC_FORMAT[mime] || EXT_TO_DOC_FORMAT[File.extname(name).delete_prefix('.')] || 'txt'
        end
      end
    end
  end
end
