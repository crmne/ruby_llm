# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Handles formatting of media content (images, PDFs, audio) for Anthropic
      module Media
        module_function

        def supported_attachment?(attachment)
          attachment.provider_file? || %i[image pdf text].include?(attachment.type)
        end

        def render_content(content, attachments = [], citations: false)
          parts = []
          parts << render_text(content) unless content.nil? || content.empty?

          attachments.each do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            if attachment.provider_file?
              parts << render_provider_file(attachment, citations: citations)
              next
            end

            case attachment.type
            when :image
              parts << render_image(attachment)
            when :pdf
              parts << render_pdf(attachment, citations: citations)
            when :text
              parts << (citations ? render_text_document(attachment) : render_text_file(attachment))
            end
          end

          parts
        end

        def render_text(text)
          {
            type: 'text',
            text: text
          }
        end

        def render_image(image)
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

        def render_provider_file(file, citations: false)
          return render_provider_image(file) if file.image?

          document = {
            type: 'document',
            source: {
              type: 'file',
              file_id: file.provider_file_id
            }
          }
          enable_citations(document, file) if citations
          document
        end

        def render_provider_image(image)
          {
            type: 'image',
            source: {
              type: 'file',
              file_id: image.provider_file_id
            }
          }
        end

        def render_pdf(pdf, citations: false)
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

        def render_text_file(text_file)
          {
            type: 'text',
            text: text_file.for_llm
          }
        end

        # Text attachments become citable documents when citations are enabled.
        def render_text_document(text_file)
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
