# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Handles formatting of media content (images, audio) for Ollama APIs
      module Media
        module_function

        def supported_attachment?(attachment)
          %i[image audio text].include?(attachment.type)
        end

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              format_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.format_audio(attachment)
            when :text
              Protocols::ChatCompletions::Media.format_text_file(attachment)
            end
          end
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: {
              url: image.for_llm,
              detail: 'auto'
            }
          }
        end
      end
    end
  end
end
