# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Handles formatting of media content (images, audio) for OpenAI APIs
      module Media
        extend OpenAI::Media

        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return format_text(content) unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment
            when Attachments::Image
              parts << Ollama::Media.format_image(attachment)
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
              url: "data:#{image.mime_type};base64,#{image.encoded}",
              detail: 'auto'
            }
          }
        end
      end
    end
  end
end
