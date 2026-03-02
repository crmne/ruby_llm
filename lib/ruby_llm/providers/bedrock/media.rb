# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Media formatting for Bedrock Converse content blocks.
      module Media
        module_function

        def render_content(content, used_document_names: nil)
          return [] if empty_content?(content)
          return render_raw_content(content) if content.is_a?(RubyLLM::Content::Raw)
          return [{ text: content.to_json }] if content.is_a?(Hash) || content.is_a?(Array)
          return [{ text: content }] unless content.is_a?(RubyLLM::Content)

          render_content_object(content, used_document_names || {})
        end

        def empty_content?(content)
          content.nil? || (content.respond_to?(:empty?) && content.empty?)
        end

        def render_content_object(content, used_document_names)
          blocks = []
          blocks << { text: content.text } if content.text
          content.attachments.each do |attachment|
            blocks << render_attachment(attachment, used_document_names:)
          end
          blocks
        end

        def render_raw_content(content)
          value = content.value
          value.is_a?(Array) ? value : [value]
        end

        def render_attachment(attachment, used_document_names:)
          case attachment.type
          when :image
            render_image_attachment(attachment)
          when :pdf
            render_document_attachment(attachment, used_document_names:)
          when :text
            { text: attachment.for_llm }
          else
            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def render_image_attachment(attachment)
          {
            image: {
              format: attachment.format,
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def render_document_attachment(attachment, used_document_names:)
          document_name = unique_document_name(sanitize_document_name(attachment.filename), used_document_names)
          {
            document: {
              format: attachment.format,
              name: document_name,
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def sanitize_document_name(filename)
          base = File.basename(filename.to_s, '.*')
          safe = base.gsub(/[^a-zA-Z0-9_-]/, '_')
          safe.empty? ? 'document' : safe
        end

        def unique_document_name(base_name, used_names)
          count = used_names[base_name].to_i
          used_names[base_name] = count + 1
          return base_name if count.zero?

          "#{base_name}_#{count + 1}"
        end
      end
    end
  end
end
