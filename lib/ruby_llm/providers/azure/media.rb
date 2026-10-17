# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Handles formatting of media content (images, audio) for Azure OpenAI-compatible APIs.
      module Media
        module_function

        def supported_attachment?(attachment)
          %i[image audio text].include?(attachment.type)
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              Protocols::ChatCompletions::Media.with_image_detail(render_image(attachment), attachment,
                                                                  original_detail: true)
            when :audio
              Protocols::ChatCompletions::Media.render_audio(attachment)
            when :text
              Protocols::ChatCompletions::Media.render_text_file(attachment)
            end
          end
        end

        def render_image(image)
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
