# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Media handling methods for the Bedrock API integration
      module Media
        extend Anthropic::Media

        module_function

        def format_content(content) # rubocop:disable Metrics/MethodLength
          return content unless content.is_a?(Content)

          parts = []
          parts << Anthropic::Media.format_text_block(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment
            when Attachments::Image
              parts << format_image(attachment)
            when Attachments::PDF
              parts << format_pdf(attachment)
            else
              raise "Unsupported attachment type: #{attachment.class}"
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: image.mime_type,
              data: image.encoded
            }
          }
        end

        def format_pdf(pdf)
          {
            type: 'document',
            source: {
              type: 'base64',
              media_type: 'application/pdf',
              data: pdf.encoded
            }
          }
        end
      end
    end
  end
end
