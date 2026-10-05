# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Formats media content for GPUStack chat completions.
      module Media
        module_function

        def supported_attachment?(attachment)
          %i[image audio video text].include?(attachment.type)
        end

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              format_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.format_audio(attachment)
            when :video
              format_video(attachment)
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

        def format_video(video)
          {
            type: 'video_url',
            video_url: { url: video.for_llm }
          }
        end
      end
    end
  end
end
