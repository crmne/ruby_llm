# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Handles media content for Mistral Chat Completions.
      module Media
        module_function

        def format_content(content) # rubocop:disable Metrics/PerceivedComplexity
          if content.is_a?(RubyLLM::Content::Raw)
            value = content.value
            return value.is_a?(Hash) ? value.to_json : value
          end
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
            when :pdf, :document
              parts << format_document(attachment)
            when :text
              parts << OpenAI::Media.format_text_file(attachment)
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts
        end

        def format_image(image)
          {
            type: 'image_url',
            image_url: image.url? ? image.source.to_s : image.for_llm
          }
        end

        def format_document(document)
          {
            type: 'document_url',
            document_url: document.url? ? document.source.to_s : document.for_llm
          }
        end
      end
    end
  end
end
