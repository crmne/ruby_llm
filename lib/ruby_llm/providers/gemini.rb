# frozen_string_literal: true

module RubyLLM
  module Providers
    # Native Gemini API implementation
    class Gemini < Provider
      include Gemini::Chat
      include Gemini::Embeddings
      include Gemini::Images
      include Gemini::Models
      include Gemini::Transcription
      include Gemini::Streaming
      include Gemini::Tools
      include Gemini::Media

      def api_base
        @config.gemini_api_base || 'https://generativelanguage.googleapis.com/v1beta'
      end

      def headers
        {
          'x-goog-api-key' => @config.gemini_api_key
        }
      end

      def preprocess_message(message)
        return message unless message.content.is_a?(Content)

        large_attachments = find_large_attachments(message.content.attachments)
        return message if large_attachments.empty?

        transform_message_with_uploads(message, large_attachments)
      end

      private

      def find_large_attachments(attachments)
        threshold = @config.gemini_large_file_threshold || 20_000_000
        attachments.select do |attachment|
          attachment.size && attachment.size > threshold
        end
      end

      def transform_message_with_uploads(message, large_attachments)
        message.dup.tap do |new_message|
          content = message.content.dup
          content.instance_variable_set(:@attachments, message.content.attachments.map do |att|
            if large_attachments.include?(att)
              # Upload and replace with URI
              file_uri = upload_attachment(att)
              create_attachment_from_uri(file_uri, att.filename)
            else
              att
            end
          end)
          new_message.content = content
        end
      end

      def create_attachment_from_uri(uri, filename)
        Attachment.new(uri, filename:)
      end

      def upload_attachment(attachment)
        service = FileUploadService.new(@connection, @config)
        service.upload(attachment)
      end

      class << self
        def capabilities
          Gemini::Capabilities
        end

        def configuration_requirements
          %i[gemini_api_key]
        end
      end
    end
  end
end
