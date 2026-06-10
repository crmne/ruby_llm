# frozen_string_literal: true

module RubyLLM
  module Providers
    class Ollama
      # Handles formatting of media content (images, audio) for Ollama APIs
      module Media
        module_function

        def format_content(content)
          OpenAI::Media.format_parts(content) do |attachment|
            case attachment.type
            when :image
              format_image(attachment)
            when :text
              OpenAI::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
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
