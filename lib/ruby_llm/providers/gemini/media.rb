# frozen_string_literal: true

module RubyLLM
  module Providers
    class Gemini # rubocop:disable Style/Documentation
      # Media handling methods for the Gemini API integration
      module Media
        module_function

        def format_content(content)
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return [format_text(content.to_json)] if content.is_a?(Hash) || content.is_a?(Array)
          return [format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :text
              parts << format_text_file(attachment)
            when :unknown
              raise UnsupportedAttachmentError, attachment.mime_type
            else
              parts << format_attachment(attachment)
            end
          end

          parts
        end

        def format_attachment(attachment)
          {
            inline_data: {
              mime_type: attachment.mime_type,
              data: attachment.encoded
            }
          }
        end

        def format_text_file(text_file)
          {
            text: text_file.for_llm
          }
        end

        def format_text(text)
          {
            text: text
          }
        end
      end

      def build_response_content(parts) # rubocop:disable Metrics/PerceivedComplexity
        text = []
        attachments = []

        parts.each_with_index do |part, index|
          if part['text']
            text << part['text']
          elsif part['inlineData']
            attachment = build_inline_attachment(part['inlineData'], index)
            attachments << attachment if attachment
          elsif part['fileData']
            attachment = build_file_attachment(part['fileData'], index)
            attachments << attachment if attachment
          end
        end

        text = text.join
        text = nil if text.empty?
        return text if attachments.empty?

        Content.new(text:, attachments:)
      end

      def build_inline_attachment(inline_data, index)
        encoded = inline_data['data']
        return unless encoded

        mime_type = inline_data['mimeType']
        decoded = Base64.decode64(encoded)
        io = StringIO.new(decoded)
        io.set_encoding(Encoding::BINARY) if io.respond_to?(:set_encoding)

        filename = attachment_filename(mime_type, index)
        RubyLLM::Attachment.new(io, filename:)
      rescue ArgumentError => e
        RubyLLM.logger.warn "Failed to decode Gemini inline data attachment: #{e.message}"
        nil
      end

      def build_file_attachment(file_data, index)
        uri = file_data['fileUri']
        return unless uri

        filename = file_data['filename'] || attachment_filename(file_data['mimeType'], index)
        RubyLLM::Attachment.new(uri, filename:)
      end

      def attachment_filename(mime_type, index)
        return "gemini_attachment_#{index + 1}" unless mime_type

        extension = mime_type.split('/').last.to_s
        extension = 'jpg' if extension == 'jpeg'
        extension = 'txt' if extension == 'plain'
        extension = extension.tr('+', '.')
        "gemini_attachment_#{index + 1}.#{extension}"
      end
    end
  end
end
