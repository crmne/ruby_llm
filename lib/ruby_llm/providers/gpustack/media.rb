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

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              render_image(attachment)
            when :audio
              Protocols::ChatCompletions::Media.render_audio(attachment)
            when :video
              render_video(attachment)
            when :text
              Protocols::ChatCompletions::Media.render_text_file(attachment)
            end
          end
        end

        def render_image(image)
          {
            type: 'image_url',
            image_url: {
              url: image.for_llm,
              detail: 'auto'
            }
          }
        end

        def render_video(video)
          {
            type: 'video_url',
            video_url: { url: video.for_llm }
          }
        end
      end
    end
  end
end
