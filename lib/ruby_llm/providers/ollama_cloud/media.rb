# frozen_string_literal: true

module RubyLLM
  module Providers
    class OllamaCloud
      # Handles formatting of media content for Ollama Cloud APIs
      module Media
        extend self

        def format_content(content)
          return content.value if content.is_a?(RubyLLM::Content::Raw)
          return content.to_json if content.is_a?(Hash) || content.is_a?(Array)
          return content unless content.is_a?(Content)

          # For Ollama, we typically send text and image URLs
          parts = []
          parts << content.text if content.text

          content.attachments.each do |attachment|
            case attachment.type
            when :image
              # Ollama expects images as base64 or URLs in the content
              parts << { type: 'image',
                         source: { type: 'base64', media_type: attachment.mime_type, data: attachment.for_llm } }
            when :text
              parts << attachment.for_llm
            else
              raise UnsupportedAttachmentError, attachment.mime_type
            end
          end

          parts.length == 1 ? parts.first : parts
        end
      end
    end
  end
end
