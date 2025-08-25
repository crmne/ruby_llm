# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Media handling methods for the Bedrock API integration
      # NOTE: Bedrock does not support url attachments
      module Media
        extend Anthropic::Media

        module_function

        def format_content(content, cache: false)
          return [Anthropic::Media.format_text(content.to_json, cache:)] if content.is_a?(Hash) || content.is_a?(Array)
          return [Anthropic::Media.format_text(content, cache:)] unless content.is_a?(Content)

          parts = []
          parts << Anthropic::Media.format_text(content.text, cache:) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment, cache:)
            when :pdf
              parts << format_pdf(attachment, cache:)
            when :text
              parts << Anthropic::Media.format_text_file(attachment, cache:)
            else
              raise UnsupportedAttachmentError, attachment.type
            end
          end

          parts
        end

        def format_image(image, cache: false)
          with_cache_control(
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: image.mime_type,
                data: image.encoded
              }
            },
            cache:
          )
        end

        def format_pdf(pdf, cache: false)
          with_cache_control(
            {
              type: 'document',
              source: {
                type: 'base64',
                media_type: pdf.mime_type,
                data: pdf.encoded
              }
            },
            cache:
          )
        end

        def with_cache_control(hash, cache: false)
          return hash unless cache

          hash.merge(cache_control: { type: 'ephemeral' })
        end
      end
    end
  end
end
