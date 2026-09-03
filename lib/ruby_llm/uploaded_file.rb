# frozen_string_literal: true

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
    include Inspectable

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

    EXPIRY_MARGIN = 60 # seconds

    # Returns +true+ once the provider's retention window for this file has
    # passed or is about to; a file expiring within the next minute cannot
    # safely serve a request. Files without a reported expiry never expire.
    def expired?
      !expires_at.nil? && expires_at <= Time.now + EXPIRY_MARGIN
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
    # Anything else goes through +provider_options:+ in the provider's own
    # vocabulary: +visibility:+ on Mistral, +display_name:+ on Gemini, and
    # +uri:+ and +content_type:+ on the storage-backed providers (Vertex AI
    # and Bedrock).
    def inspect_attributes # :nodoc:
      { id: id, provider: provider, filename: filename, byte_size: byte_size }
    end

    def self.upload(file, provider: nil, context: nil, filename: nil, purpose: nil, expires_in: nil,
                    provider_options: {})
      provider_for(provider, context).upload_file(file, filename:, purpose:, expires_in:, provider_options:)
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
