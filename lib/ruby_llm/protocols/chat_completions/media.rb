# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Handles formatting of media content (images, audio) for OpenAI APIs
      module Media
        module_function

        def format_content(content, document_attachments: :pdf, image_attachments: true, audio_attachments: true)
          format_parts(content) do |attachment|
            format_attachment(
              attachment,
              document_attachments:,
              image_attachments:,
              audio_attachments:
            )
          end
        end

        # Shared preamble and attachment loop for OpenAI-compatible providers.
        # The block formats a single attachment in the provider's dialect.
        def format_parts(content)
          if content.is_a?(RubyLLM::Content::Raw)
            value = content.value
            return value.is_a?(Hash) ? value.to_json : value
          end
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            parts << yield(attachment)
          end

          parts
        end

        def format_attachment(attachment, document_attachments:, image_attachments:, audio_attachments:)
          case attachment.type
          when :image
            raise UnsupportedAttachmentError, attachment.mime_type unless image_attachments

            format_image(attachment)
          when :audio
            raise UnsupportedAttachmentError, attachment.mime_type unless audio_attachments

            format_audio(attachment)
          when :pdf, :document
            format_document_attachment(attachment, document_attachments)
          when :text
            format_text_file(attachment)
          else
            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: {
              url: image.url? ? image.source.to_s : image.for_llm
            }
          }
        end

        def format_document(document)
          {
            type: 'file',
            file: {
              filename: document.filename,
              file_data: document.for_llm
            }
          }
        end

        def format_text_file(text_file)
          {
            type: 'text',
            text: text_file.for_llm
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

        def format_text(text)
          {
            type: 'text',
            text: text
          }
        end

        def format_document_attachment(attachment, strategy)
          return format_document(attachment) if strategy == :all
          return format_document(attachment) if strategy == :pdf && attachment.pdf?

          raise UnsupportedAttachmentError, attachment.mime_type
        end
      end
    end
  end
end
