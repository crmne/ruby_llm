# frozen_string_literal: true

module RubyLLM
  module Providers
    module Anthropic
      # Handles formatting of media content (images, PDFs, audio) for Anthropic
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return [format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment
            when Attachments::Image
              parts << format_image(attachment)
            when Attachments::PDF
              parts << format_pdf(attachment)
            end
          end

          parts
        end

        def format_text(text)
          {
            type: 'text',
            text: text
          }
        end

        def format_image(image) # rubocop:disable Metrics/MethodLength
          if image.url?
            {
              type: 'image',
              source: {
                type: 'url',
                url: image.source
              }
            }
          else
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: image.mime_type,
                data: image.encoded
              }
            }
          end
        end

        def format_pdf(pdf) # rubocop:disable Metrics/MethodLength
          if pdf.url?
            {
              type: 'document',
              source: {
                type: 'url',
                url: pdf.source
              }
            }
          else
            {
              type: 'document',
              source: {
                type: 'base64',
                media_type: 'application/pdf',
                data: pdf.encoded
              }
            }
          end
        end
      end
    end
  end
end
