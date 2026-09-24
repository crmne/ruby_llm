# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Handles media content for Mistral Chat Completions.
      module Media
        module_function

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_parts(content, attachments) do |attachment|
            case attachment.type
            when :image
              format_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.format_audio(attachment)
            when :pdf, :document
              format_document(attachment)
            when :text
              Protocols::ChatCompletions::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: image.url_or_data_uri
          }
        end

        def format_document(document)
          {
            type: 'document_url',
            document_url: document.url_or_data_uri
          }
        end
      end
    end
  end
end
