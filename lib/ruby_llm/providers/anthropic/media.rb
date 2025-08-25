# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Handles formatting of media content (images, PDFs, audio) for Anthropic
      module Media
        module_function

        def format_content(content, cache: false)
          return [format_text(content.to_json, cache:)] if content.is_a?(Hash) || content.is_a?(Array)
          return [format_text(content, cache:)] unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text, cache:) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :pdf
              parts << format_pdf(attachment)
            when :text
              parts << format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts
        end

        def format_text(text, cache: false)
          with_cache_control(
            {
              type: 'text',
              text: text
            },
            cache:
          )
        end

        def format_image(image, cache: false)
          if image.url?
            with_cache_control(
              {
                type: 'image',
                source: {
                  type: 'url',
                  url: image.source
                }
              },
              cache:
            )
          else
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
        end

        def format_pdf(pdf, cache: false)
          if pdf.url?
            with_cache_control(
              {
                type: 'document',
                source: {
                  type: 'url',
                  url: pdf.source
                }
              },
              cache:
            )
          else
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
        end

        def format_text_file(text_file, cache: false)
          with_cache_control(
            {
              type: 'text',
              text: Utils.format_text_file_for_llm(text_file)
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
