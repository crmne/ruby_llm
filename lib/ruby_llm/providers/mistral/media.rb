# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Handles media content for Mistral Chat Completions.
      module Media
        module_function

        def format_content(content)
          Protocols::ChatCompletions::Media.format_parts(content) do |attachment|
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
            image_url: image.url? ? image.source.to_s : image.for_llm
          }
        end

        def format_document(document)
          {
            type: 'document_url',
            document_url: document.url? ? document.source.to_s : document.for_llm
          }
        end
      end
    end
  end
end
