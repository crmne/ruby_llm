# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Handles formatting of media content (images, PDFs, audio) for Anthropic
      module Media
        module_function

        def format_content(content, citations: false) # rubocop:disable Metrics/PerceivedComplexity
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return [format_text(content.to_json)] if content.is_a?(Hash) || content.is_a?(Array)
          return [format_text(content)] unless content.is_a?(RubyLLM::Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :pdf
              parts << format_pdf(attachment, citations: citations)
            when :text
              parts << (citations ? format_text_document(attachment) : format_text_file(attachment))
            else
              raise UnsupportedAttachmentError, attachment.mime_type
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

        def format_image(image)
          if image.url?
            {
              type: 'image',
              source: {
                type: 'url',
                url: image.source.to_s
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

        def format_pdf(pdf, citations: false)
          document = {
            type: 'document',
            source: pdf_source(pdf)
          }

          enable_citations(document, pdf) if citations
          document
        end

        def pdf_source(pdf)
          if pdf.url?
            {
              type: 'url',
              url: pdf.source.to_s
            }
          else
            {
              type: 'base64',
              media_type: pdf.mime_type,
              data: pdf.encoded
            }
          end
        end

        def format_text_file(text_file)
          {
            type: 'text',
            text: text_file.for_llm
          }
        end

        # Text attachments become citable documents when citations are enabled.
        def format_text_document(text_file)
          document = {
            type: 'document',
            source: {
              type: 'text',
              media_type: 'text/plain',
              data: text_file.content
            }
          }

          enable_citations(document, text_file)
          document
        end

        def enable_citations(document, attachment)
          document[:title] = attachment.filename if attachment.filename
          document[:citations] = { enabled: true }
        end
      end
    end
  end
end
