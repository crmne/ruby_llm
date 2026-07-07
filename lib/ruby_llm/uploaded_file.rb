# frozen_string_literal: true

require 'stringio'

module RubyLLM
  # An UploadedFile is the metadata record for a file stored with a provider
  # through its Files API. Upload a file once with ::upload, then reuse its
  # provider id or URI, for example as a chat attachment or in a batch.
  #
  #   file = RubyLLM.upload("batch.jsonl", purpose: "batch")
  #   file.id         # => "file_..."
  #   file.filename   # => "batch.jsonl"
  #   file.byte_size  # => 1234
  #
  # File ids are provider-owned. Persist #provider alongside #id and pass it
  # back when finding or downloading the file later.
  class UploadedFile
    # The provider-assigned file identifier, such as <tt>"file_..."</tt>.
    attr_reader :id

    # The slug of the provider that stores the file.
    attr_reader :provider

    # The filename reported by the provider.
    attr_reader :filename

    # The file size in bytes.
    attr_reader :byte_size

    # The Time the provider stored the file.
    attr_reader :created_at

    # The Time the provider will delete the file, or +nil+ if it does not
    # expire.
    attr_reader :expires_at

    # The provider-reported processing status of the file.
    attr_reader :status

    # The MIME type of the stored file.
    attr_reader :mime_type

    # The purpose the file was uploaded for, such as <tt>"batch"</tt>, when
    # the provider tracks one.
    attr_reader :purpose

    # The provider URI for the file, such as a Gemini Files API URI or a
    # <tt>gs://</tt> or <tt>s3://</tt> location for storage-backed providers.
    attr_reader :uri

    # Whether the provider allows downloading the file's content.
    attr_reader :downloadable

    # The raw provider response data for the file, as a Hash.
    attr_reader :metadata

    def initialize(id:, **attributes) # :nodoc:
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

    class Protocol # :nodoc:
      attr_reader :provider, :config, :connection

      def initialize(provider)
        @provider = provider
        @config = provider.config
        @connection = provider.connection
      end

      def upload(file, filename: nil, purpose: nil, expires_in: nil, visibility: nil, # rubocop:disable Metrics/ParameterLists
                 display_name: nil, uri: nil, content_type: nil)
        attachment = file_attachment(file, filename:)
        options = { purpose:, expires_in:, visibility:, display_name:, uri:, content_type: }.compact
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

      # rubocop:disable Lint/UnusedMethodArgument, Metrics/ParameterLists
      def render_upload_payload(attachment, purpose: nil, expires_in: nil, visibility: nil,
                                display_name: nil, uri: nil, content_type: nil)
        { file: file_part(attachment) }
      end
      # rubocop:enable Lint/UnusedMethodArgument, Metrics/ParameterLists

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

    # Uploads +file+ to the provider's Files API and returns an UploadedFile.
    # +file+ may be a path, an IO object, or an Attachment. When +provider:+
    # is omitted, the provider of the configured default model is used.
    # Also available as RubyLLM.upload.
    #
    #   RubyLLM::UploadedFile.upload("document.pdf", provider: :anthropic)
    #   RubyLLM::UploadedFile.upload(io, provider: :openai, purpose: "batch",
    #                                filename: "batch.jsonl")
    #
    # OpenAI and Azure require +purpose:+. Pass +expires_in:+ as a number of
    # seconds to have the provider delete the file automatically; OpenAI,
    # xAI, and Mistral support it, and Mistral rounds up to whole hours.
    # The remaining keywords are provider-specific options: +visibility:+
    # (Mistral), +display_name:+ (Gemini), and +uri:+ and +content_type:+
    # (storage-backed providers such as Vertex AI and Bedrock).
    def self.upload(file, provider: nil, context: nil, filename: nil, purpose: nil, expires_in: nil, # rubocop:disable Metrics/ParameterLists
                    visibility: nil, display_name: nil, uri: nil, content_type: nil)
      options = { filename:, purpose:, expires_in:, visibility:, display_name:, uri:, content_type: }
                .compact

      provider_for(provider, context).upload_file(file, **options)
    end

    # Fetches metadata for an existing provider file by +id+ and returns an
    # UploadedFile. When +provider:+ is omitted, the provider of the
    # configured default model is used.
    #
    #   file = RubyLLM::UploadedFile.find("file_123")
    #
    def self.find(id, provider: nil, context: nil)
      provider_for(provider, context).find_file(id)
    end

    # Downloads the content of the provider file +id+ and returns the raw
    # body. Also available as RubyLLM.download.
    #
    #   content = RubyLLM.download(file.id)
    #
    # Not every provider allows downloads; see #downloadable.
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
