# frozen_string_literal: true

# lib/ruby_llm/providers/openai/media.rb
module RubyLLM
  module Providers
    module OpenAI
      # Handles formatting of media content (images, audio) for OpenAI APIs
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return content unless content.is_a?(Content)

          parts = []
          parts << content.text if content.text

          content.attachments.each do |attachment|
            case attachment
            when Attachments::Image
              parts << format_image(attachment)
            when Attachments::PDF
              parts << format_pdf(attachment)
            when Attachments::Audio
              parts << format_audio(attachment)
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: {
              url: image.url? ? image.source : "data:#{image.mime_type};base64,#{image.encoded}",
              detail: 'auto'
            }
          }
        end

        def format_pdf(pdf)
          {
            type: 'file',
            file: {
              filename: File.basename(pdf.source),
              file_data: "data:#{pdf.mime_type};base64,#{pdf.encoded}"
            }
          }
        end

        def format_audio(audio)
          {
            type: 'input_audio',
            input_audio: {
              data: audio.encoded,
              format: audio.format
            }
          }
        end
      end
    end
  end
end
