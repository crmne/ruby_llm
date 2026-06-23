# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Handles formatting of media content for the OpenAI Responses API
      module Media
        module_function

        def format_content(content)
          if content.is_a?(RubyLLM::Content::Raw)
            value = content.value
            return value.is_a?(Hash) ? value.to_json : value
          end
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          parts = []
          parts << { type: 'input_text', text: content.text } if content.text
          content.attachments.each { |attachment| parts << format_attachment(attachment) }
          parts
        end

        def format_attachment(attachment)
          return format_provider_file(attachment) if attachment.provider_file?

          case attachment.type
          when :image
            format_image(attachment)
          when :pdf, :document
            format_document(attachment)
          when :text
            { type: 'input_text', text: attachment.for_llm }
          else
            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def format_image(image)
          {
            type: 'input_image',
            image_url: image.url? ? image.source.to_s : image.for_llm
          }
        end

        def format_document(document)
          raise UnsupportedAttachmentError, document.mime_type unless document.pdf?

          {
            type: 'input_file',
            filename: document.filename,
            file_data: document.for_llm
          }
        end

        def format_provider_file(file)
          {
            type: 'input_file',
            file_id: file.provider_file_id
          }
        end
      end
    end
  end
end
