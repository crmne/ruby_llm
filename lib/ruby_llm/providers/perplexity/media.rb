# frozen_string_literal: true

module RubyLLM
  module Providers
    class Perplexity
      # Handles Perplexity Sonar media content.
      module Media
        module_function

        def supported_attachment?(attachment)
          %i[image pdf document text].include?(attachment.type)
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            raise UnsupportedAttachmentError, attachment.mime_type unless supported_attachment?(attachment)

            case attachment.type
            when :image
              Protocols::ChatCompletions::Media.render_image(attachment)
            when :pdf, :document
              render_document(attachment)
            when :text
              Protocols::ChatCompletions::Media.render_text_file(attachment)
            end
          end
        end

        def render_document(attachment)
          {
            type: 'file_url',
            file_url: {
              url: attachment.url? ? attachment.source.to_s : attachment.encoded
            }
          }
        end
      end
    end
  end
end
