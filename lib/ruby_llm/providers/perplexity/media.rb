# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Handles Perplexity Sonar media content.
      module Media
        module_function

        SUPPORTED_DOCUMENT_EXTENSIONS = %w[pdf doc docx txt rtf].freeze

        def format_content(content) # rubocop:disable Metrics/PerceivedComplexity
          if content.is_a?(RubyLLM::Content::Raw)
            value = content.value
            return value.is_a?(Hash) ? value.to_json : value
          end
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          parts = []
          parts << OpenAI::Media.format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << OpenAI::Media.format_image(attachment)
            when :pdf, :document
              parts << format_document(attachment)
            when :text
              parts << format_text_attachment(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts
        end

        def format_document(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type unless supported_file?(attachment)

          {
            type: 'file_url',
            file_url: {
              url: attachment.url? ? attachment.source.to_s : attachment.encoded
            }
          }
        end

        def format_text_attachment(attachment)
          return format_document(attachment) if supported_file?(attachment)

          OpenAI::Media.format_text_file(attachment)
        end

        def supported_file?(attachment)
          return true if attachment.pdf?

          SUPPORTED_DOCUMENT_EXTENSIONS.include?(attachment.extension)
        end
      end
    end
  end
end
