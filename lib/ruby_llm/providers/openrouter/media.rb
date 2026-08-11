# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenRouter
      # Handles media content for OpenRouter, which adds video input parts
      # to the standard Chat Completions vocabulary.
      module Media
        module_function

        def format_content(content, attachments = [])
          Protocols::ChatCompletions::Media.format_parts(content, attachments) do |attachment|
            if attachment.type == :video
              format_video(attachment)
            else
              Protocols::ChatCompletions::Media.format_attachment(
                attachment, document_attachments: :pdf, image_attachments: true, audio_attachments: true
              )
            end
          end
        end

        def format_video(video)
          {
            type: 'video_url',
            video_url: {
              url: video.url? ? video.source.to_s : video.for_llm
            }
          }
        end
      end
    end
  end
end
