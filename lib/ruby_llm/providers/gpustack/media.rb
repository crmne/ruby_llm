# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Handles formatting of media content for GPUStack. Images ride inline
      # as base64 data URLs so the cluster never has to fetch remote sources.
      module Media
        module_function

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_parts(content, attachments) do |attachment|
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
              url: image.for_llm,
              detail: 'auto'
            }
          }
        end
      end
    end
  end
end
