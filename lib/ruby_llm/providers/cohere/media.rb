# frozen_string_literal: true

module RubyLLM
  module Providers
    module Cohere
      # Handles formatting of media content (images) for Cohere APIs
      # Supports Aya Vision models with multimodal capabilities
      module Media
        module_function

        def format_content(content)
          return [format_text(content)] unless content.is_a?(RubyLLM::Content)

          parts = []
          parts << format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :text
              parts << format_text_file(attachment)
            else
              raise RubyLLM::UnsupportedAttachmentError, attachment.type
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
          if image.url?
            # Use URL directly for Cohere API
            {
              type: 'image_url',
              image_url: {
                url: image.source
              }
            }
          else
            # Use base64 encoding for local images
            {
              type: 'image_url',
              image_url: {
                url: "data:#{image.mime_type};base64,#{image.encoded}"
              }
            }
          end
        end

        def format_text_file(text_file)
          {
            type: 'text',
            text: Utils.format_text_file_for_llm(text_file)
          }
        end
      end
    end
  end
end
