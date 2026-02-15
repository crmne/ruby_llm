# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Handles formatting of media content (images, audio) for Azure OpenAI-compatible APIs.
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/PerceivedComplexity
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          parts = []
          parts << OpenAI::Media.format_text(content.text) if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              parts << format_image(attachment)
            when :audio
              parts << OpenAI::Media.format_audio(attachment)
            when :text
              parts << OpenAI::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.type
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: {
              url: image.for_llm
            }
          }
        end
      end
    end
  end
end
