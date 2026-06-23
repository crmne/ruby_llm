# frozen_string_literal: true

require 'stringio'

module RubyLLM
  # Metadata for a file stored by a provider.
  class UploadedFile
    attr_reader :id, :provider, :filename, :byte_size, :created_at, :expires_at, :status, :mime_type, :purpose, :uri,
                :downloadable, :metadata

    def initialize(id:, **attributes)
      @id = id
      @provider = attributes[:provider]
      @filename = attributes[:filename]
      @byte_size = attributes[:byte_size]
      @created_at = attributes[:created_at]
      @expires_at = attributes[:expires_at]
      @status = attributes[:status]
      @mime_type = attributes[:mime_type]
      @purpose = attributes[:purpose]
      @uri = attributes[:uri]
      @downloadable = attributes[:downloadable]
      @metadata = attributes[:metadata] || {}
    end

    # Shared executor for provider-managed file APIs. The public API lives on
    # UploadedFile; concrete wire formats live under their owning protocol or
    # provider namespace.
    class Protocol
      attr_reader :provider, :config, :connection

      def initialize(provider)
        @provider = provider
        @config = provider.config
        @connection = provider.connection
      end

      def upload(file, filename: nil, **options)
        attachment = file_attachment(file, filename:)
        response = @connection.post(files_url, render_upload_payload(attachment, **options)) do |request|
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

      def render_upload_payload(attachment, **)
        { file: file_part(attachment) }
      end

      def multipart_payload(attachment, **fields)
        { file: file_part(attachment) }.merge(fields.compact)
      end

      def upload_headers(_request); end

      def file_headers(_request); end

      def file_attachment(file, filename: nil)
        file.is_a?(Attachment) && filename.nil? ? file : Attachment.new(file, filename:)
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
        return Time.at(value) if value.to_s.match?(/\A\d+\z/)

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

    def self.upload(file, provider: nil, context: nil, **options)
      provider_for(provider, context).upload_file(file, **options)
    end

    def self.find(id, provider: nil, context: nil)
      provider_for(provider, context).find_file(id)
    end

    def self.download(id, provider: nil, context: nil)
      provider_for(provider, context).download_file(id)
    end

    def self.provider_for(provider, context)
      config = context&.config || RubyLLM.config

      if provider
        Provider.resolve!(provider).new(config)
      else
        Models.resolve(config.default_model, config:).last
      end
    end
    private_class_method :provider_for
  end
end
