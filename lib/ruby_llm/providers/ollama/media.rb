# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Handles formatting of media content (images, audio) for OpenAI APIs
      module Media
        extend OpenAI::Media

        module_function

        def format_content(content)
          return content unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << Ollama::Media.format_image(attachment)
            when :pdf
              parts << format_pdf(attachment)
            when :audio
              parts << format_audio(attachment)
            when :text
              parts << format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: {
              url: "data:#{image.mime_type};base64,#{image.encoded}",
              detail: 'auto'
            }
          }
        end
      end
    end
  end
end
