# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      # Handles formatting of media content for the Cohere v2 API
      module Media
        module_function

        # Cohere user messages accept only text and image_url blocks. Text
        # attachments become citable documents when citations are on, so they
        # are pulled out of the message and left out of the content blocks.
        def format_content(content, attachments = [], citations: false)
          parts = []
          parts << format_text(content) if content

          attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :text
              parts << format_text(attachment.for_llm) unless citations
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts
        end

        def format_text(text)
          {
            type: 'text',
            text: text
          }
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: { url: image.url? ? image.source.to_s : "data:#{image.mime_type};base64,#{image.encoded}" }
          }
        end

        # Text attachments across the conversation become the request's
        # top-level documents array, which is what Cohere cites against.
        def format_documents(messages)
          index = -1

          messages.flat_map do |message|
            message.attachments.select(&:text?).map do |attachment|
              index += 1
              {
                id: "doc:#{index}",
                data: { title: attachment.filename, text: attachment.content }.compact
              }
            end
          end
        end

        def documents?(messages)
          messages.any? { |message| message.attachments.any?(&:text?) }
        end
      end
    end
  end
end
