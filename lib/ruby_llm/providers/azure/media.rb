# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Handles formatting of media content (images, audio) for Azure OpenAI-compatible APIs.
      module Media
        module_function

        def format_content(content)
          Protocols::ChatCompletions::Media.format_parts(content) do |attachment|
            case attachment.type
            when :image
              format_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.format_audio(attachment)
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
            image_url: {
              url: image.for_llm
            }
          }
        end
      end
    end
  end
end
