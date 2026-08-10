# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Converse
      # Media formatting for Bedrock Converse content blocks.
      module Media
        module_function

        def format_content(content, attachments = [], used_document_names: nil, citations: false)
          used_document_names ||= {}
          blocks = []
          blocks << { text: content } unless content.nil? || content.empty?
          attachments.each do |attachment|
            blocks << format_attachment(attachment, used_document_names:, citations:)
          end
          blocks
        end

        def format_attachment(attachment, used_document_names:, citations: false)
          if attachment.provider_file?
            return format_provider_file_attachment(attachment, used_document_names:, citations:)
          end

          case attachment.type
          when :image
            format_image_attachment(attachment)
          when :audio
            format_audio_attachment(attachment)
          when :video
            format_video_attachment(attachment)
          when :pdf, :document
            format_document_attachment(attachment, used_document_names:, citations:)
          when :text
            if citations
              format_text_document_attachment(attachment, used_document_names:)
            else
              format_text_attachment(attachment)
            end
          else
            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        SUPPORTED_DOCUMENT_FORMATS = %w[pdf csv doc docx xls xlsx html txt md].freeze
        SUPPORTED_AUDIO_FORMATS = %w[mp3 opus wav aac flac mp4 ogg mkv mka x-aac m4a mpeg mpga pcm webm].freeze
        SUPPORTED_VIDEO_FORMATS = %w[mkv mov mp4 webm flv mpeg mpg wmv three_gp].freeze
        AUDIO_FORMAT_ALIASES = {
          'x-flac' => 'flac',
          'x-m4a' => 'm4a'
        }.freeze
        VIDEO_FORMAT_ALIASES = {
          'quicktime' => 'mov',
          'x-matroska' => 'mkv',
          'x-ms-wmv' => 'wmv',
          '3gp' => 'three_gp',
          '3gpp' => 'three_gp'
        }.freeze

        def format_image_attachment(attachment)
          {
            image: {
              format: attachment.format,
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def format_audio_attachment(attachment)
          {
            audio: {
              format: media_format(attachment, AUDIO_FORMAT_ALIASES, SUPPORTED_AUDIO_FORMATS),
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def format_video_attachment(attachment)
          {
            video: {
              format: media_format(attachment, VIDEO_FORMAT_ALIASES, SUPPORTED_VIDEO_FORMATS),
              source: {
                bytes: attachment.encoded
              }
            }
          }
        end

        def media_format(attachment, aliases, supported)
          format = attachment.format.to_s
          format = aliases.fetch(format, format)
          raise UnsupportedAttachmentError, attachment.mime_type unless supported.include?(format)

          format
        end

        def format_text_attachment(attachment)
          { text: attachment.for_llm }
        end

        def format_document_attachment(attachment, used_document_names:, citations: false)
          format = document_format(attachment)

          raise UnsupportedAttachmentError, attachment.mime_type unless supported_document_format?(attachment)

          document_name = unique_document_name(sanitize_document_name(attachment.filename), used_document_names)
          document = {
            format: format,
            name: document_name,
            source: {
              bytes: attachment.encoded
            }
          }
          document[:citations] = { enabled: true } if citations
          { document: document }
        end

        # Text attachments become citable documents when citations are
        # enabled. Bedrock rejects text-format documents sent as bytes when
        # citations are on, so the text rides in the source's text member.
        def format_text_document_attachment(attachment, used_document_names:)
          document_name = unique_document_name(sanitize_document_name(attachment.filename), used_document_names)
          {
            document: {
              format: 'txt',
              name: document_name,
              source: { text: attachment.content },
              citations: { enabled: true }
            }
          }
        end

        def format_provider_file_attachment(attachment, used_document_names:, citations: false)
          raise UnsupportedAttachmentError, attachment.mime_type unless supported_document_format?(attachment)

          document_name = unique_document_name(sanitize_document_name(attachment.filename), used_document_names)
          document = {
            format: document_format(attachment),
            name: document_name,
            source: {
              s3Location: {
                uri: attachment.provider_file_uri || attachment.provider_file_id
              }
            }
          }
          document[:citations] = { enabled: true } if citations
          { document: document }
        end

        def supported_document_format?(attachment)
          SUPPORTED_DOCUMENT_FORMATS.include?(document_format(attachment))
        end

        def document_format(attachment)
          attachment.extension || attachment.format
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
