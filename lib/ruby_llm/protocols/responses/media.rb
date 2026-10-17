# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Handles formatting of media content for the OpenAI Responses API
      module Media
        module_function

        def supported_attachment?(attachment)
          attachment.provider_file? || %i[image pdf document text].include?(attachment.type)
        end

        def render_content(content, attachments = [])
          return content if attachments.empty?

          parts = []
          parts << { type: 'input_text', text: content } if content
          attachments.each { |attachment| parts << render_attachment(attachment) }
          parts
        end

        def render_attachment(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

          return render_provider_file(attachment) if attachment.provider_file?

          case attachment.type
          when :image
            render_image(attachment)
          when :pdf, :document
            render_document(attachment)
          when :text
            { type: 'input_text', text: attachment.for_llm }
          end
        end

        def render_image(image, image_url: image.url_or_data_uri, original_detail: @provider&.original_image_detail?)
          part = { type: 'input_image', image_url: }
          return part unless image.resolution

          part.merge(detail: ChatCompletions::Media.image_detail(image.resolution, original_detail:))
        end

        # The Responses API extracts text from documents, presentations, and
        # spreadsheets as well as PDFs, so every document attachment rides
        # along as a native input_file.
        def render_document(document)
          {
            type: 'input_file',
            filename: document.filename,
            file_data: document.for_llm
          }
        end

        def render_provider_file(file)
          {
            type: 'input_file',
            file_id: file.provider_file_id
          }
        end
      end
    end
  end
end
