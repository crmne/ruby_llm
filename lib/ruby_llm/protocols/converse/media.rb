# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Converse
      # Media formatting for Bedrock Converse content blocks.
      module Media
        module_function

        def format_content(content, used_document_names: nil)
          return [] if empty_content?(content)
          return format_raw_content(content) if content.is_a?(RubyLLM::Content::Raw)
          return [{ text: content.to_json }] if content.is_a?(Hash) || content.is_a?(Array)
          return [{ text: content }] unless content.is_a?(RubyLLM::Content)

          format_content_object(content, used_document_names || {})
        end

        def empty_content?(content)
          content.nil? || (content.respond_to?(:empty?) && content.empty?)
        end

        def format_content_object(content, used_document_names)
          blocks = []
          blocks << { text: content.text } if content.text
          content.attachments.each do |attachment|
            blocks << format_attachment(attachment, used_document_names:)
          end
          blocks
        end

        def format_raw_content(content)
          value = content.value
          value.is_a?(Array) ? value : [value]
        end

        def format_attachment(attachment, used_document_names:)
          case attachment.type
          when :image
            format_image_attachment(attachment)
          when :pdf, :document
            format_document_attachment(attachment, used_document_names:)
          when :text
            format_text_attachment(attachment)
          else
            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        SUPPORTED_DOCUMENT_FORMATS = %w[pdf csv doc docx xls xlsx html txt md].freeze

        def format_image_attachment(attachment)
          {
            image: {
              format: attachment.format,
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def format_text_attachment(attachment)
          { text: attachment.for_llm }
        end

        def format_document_attachment(attachment, used_document_names:)
          format = document_format(attachment)

          raise UnsupportedAttachmentError, attachment.mime_type unless supported_document_format?(attachment)

          document_name = unique_document_name(sanitize_document_name(attachment.filename), used_document_names)
          {
            document: {
              format: format,
              name: document_name,
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def supported_document_format?(attachment)
          SUPPORTED_DOCUMENT_FORMATS.include?(document_format(attachment))
        end

        def document_format(attachment)
          attachment.extension || attachment.format
        end

        def sanitize_document_name(filename)
          base = File.basename(filename.to_s, '.*')
          safe = base.gsub(/[^a-zA-Z0-9_-]/, '_')
          safe.empty? ? 'document' : safe
        end

        def unique_document_name(base_name, used_names)
          count = used_names[base_name].to_i
          used_names[base_name] = count + 1
          return base_name if count.zero?

          "#{base_name}_#{count + 1}"
        end
      end
    end
  end
end
