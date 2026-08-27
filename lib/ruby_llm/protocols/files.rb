# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Protocols
    # Provider-managed file storage APIs.
    class Files < Protocol
      def upload(file, filename: nil, purpose: nil, expires_in: nil, visibility: nil,
                 display_name: nil, uri: nil, content_type: nil)
        attachment = file_attachment(file, filename:)
        options = { purpose:, expires_in:, visibility:, display_name:, uri:, content_type: }.compact
        response = @connection.post(files_url, render_upload_payload(attachment, **options),
                                    idempotent: false) do |request|
          request.headers.delete('Content-Type')
          upload_headers(request)
        end
        parse_file_response(response.body)
      end

      def find(file_id)
        response = @connection.get(file_info_url(file_id)) { |request| file_headers(request) }
        parse_file_response(response.body)
      end

      def download(file_id)
        response = @connection.get(download_file_url(file_id)) do |request|
          request.headers['Accept'] = 'application/octet-stream'
          file_headers(request)
        end
        response.body
      end

      def list_uris(_uri)
        raise Error, "#{@provider.slug} doesn't support file listing"
      end

      private

      def files_url
        'files'
      end

      def file_info_url(file_id)
        "#{files_url}/#{file_id}"
      end

      def download_file_url(file_id)
        "#{file_info_url(file_id)}/content"
      end

      # rubocop:disable-next Lint/UnusedMethodArgument
      def render_upload_payload(attachment, purpose: nil, expires_in: nil, visibility: nil,
                                display_name: nil, uri: nil, content_type: nil)
        { file: file_part(attachment) }
      end

      def multipart_payload(attachment, **fields)
        { file: file_part(attachment) }.merge(fields.compact)
      end

      def upload_headers(_request); end

      def file_headers(_request); end

      def file_attachment(file, filename: nil)
        return file if file.is_a?(Attachment) && filename.nil?

        file = file.source if file.is_a?(Attachment)
        Attachment.new(file, filename:, config:)
      end

      def file_part(attachment, content_type: nil)
        Faraday::Multipart::FilePart.new(file_part_source(attachment), content_type || file_content_type(attachment),
                                         attachment.filename)
      end

      def file_content_type(attachment)
        attachment.extension == 'jsonl' ? 'application/jsonl' : attachment.mime_type
      end

      def file_part_source(attachment)
        if attachment.path?
          attachment.source.to_s
        elsif attachment.io_like?
          attachment.source.tap { |io| io.rewind if io.respond_to?(:rewind) }
        else
          StringIO.new(attachment.content)
        end
      end

      def timestamp(value)
        return if value.nil?
        return Time.at(value) if value.is_a?(Numeric)
        return Time.at(value.to_i) if value.to_s.match?(/\A\d+\z/)

        Time.iso8601(value.to_s)
      end

      def uploaded_file(data, **attributes)
        UploadedFile.new(**attributes, provider: @provider.slug, metadata: data)
      end

      def with_file_body(attachment, &)
        if attachment.path?
          File.open(attachment.source, 'rb', &)
        else
          body = attachment.io_like? ? attachment.source : StringIO.new(attachment.content)
          body.rewind if body.respond_to?(:rewind)
          yield body
        end
      end

      def file_size(attachment)
        attachment.path? ? File.size(attachment.source) : attachment.content.bytesize
      end
    end
  end
end
