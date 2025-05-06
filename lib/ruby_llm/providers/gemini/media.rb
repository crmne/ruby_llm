# frozen_string_literal: true

module RubyLLM
  module Providers
    module Gemini
      # Media handling methods for the Gemini API integration
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return [format_text(content)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

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
            inline_data: {
              mime_type: image.mime_type,
              data: image.encoded
            }
          }
        end

        def format_pdf(pdf)
          {
            inline_data: {
              mime_type: 'application/pdf',
              data: pdf.encoded
            }
          }
        end

        def format_audio(audio)
          {
            inline_data: {
              mime_type: "audio/#{audio.format}",
              data: audio.encoded
            }
          }
        end

        def format_text(text)
          {
            text: text
          }
        end
      end
    end
  end
end
