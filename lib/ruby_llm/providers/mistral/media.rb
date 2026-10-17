# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Handles media content for Mistral Chat Completions.
      module Media
        module_function

        def supported_attachment?(attachment)
          %i[image audio pdf document text].include?(attachment.type)
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              render_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.render_audio(attachment)
            when :pdf, :document
              render_document(attachment)
            when :text
              Protocols::ChatCompletions::Media.render_text_file(attachment)
            end
          end
        end

        def render_image(image)
          {
            type: 'image_url',
            image_url: image.url_or_data_uri
          }
        end

        def render_document(document)
          {
            type: 'document_url',
            document_url: document.url_or_data_uri
          }
        end
      end
    end
  end
end
