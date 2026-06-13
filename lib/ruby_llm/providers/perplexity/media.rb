# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Handles Perplexity Sonar media content.
      module Media
        module_function

        SUPPORTED_DOCUMENT_EXTENSIONS = %w[pdf doc docx txt rtf].freeze

        def format_content(content)
          Protocols::ChatCompletions::Media.format_parts(content) do |attachment|
            case attachment.type
            when :image
              Protocols::ChatCompletions::Media.format_image(attachment)
            when :pdf, :document
              format_document(attachment)
            when :text
              Protocols::ChatCompletions::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end
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

        def supported_file?(attachment)
          return true if attachment.pdf?

          SUPPORTED_DOCUMENT_EXTENSIONS.include?(attachment.extension)
        end
      end
    end
  end
end
