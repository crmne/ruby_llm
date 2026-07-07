# frozen_string_literal: true

require 'base64'
require 'pathname'
require 'uri'

module RubyLLM
  # An Attachment is a file sent to the model alongside a message. The source
  # can be a local path, an http(s) URL, an IO-like object, an ActiveStorage
  # object, or a provider-managed UploadedFile. Chat#ask builds attachments
  # for you from its +with:+ option:
  #
  #   chat.ask "What's in this image?", with: "ruby_conf.jpg"
  #
  # Build one explicitly to return a file from a Tool:
  #
  #   RubyLLM::Attachment.new(doc.download_path)
  #
  class Attachment
    # The underlying source: a URI, Pathname, IO-like object, ActiveStorage
    # object, or UploadedFile.
    attr_reader :source

    # The filename given at construction or derived from the source.
    # May be +nil+.
    attr_reader :filename

    # The detected MIME type string, such as <tt>"image/png"</tt>.
    attr_reader :mime_type

    # File extensions recognized as document attachments when the MIME type
    # alone is inconclusive.
    DOCUMENT_EXTENSIONS = %w[
      doc docx dot key numbers odp ods odt pages pot pps ppt pptx rtf xls xlsx
    ].freeze

    # :stopdoc:
    ACTIVE_STORAGE_CLASS_NAMES = %w[
      ActiveStorage::Blob
      ActiveStorage::Attachment
      ActiveStorage::Attached::One
      ActiveStorage::Attached::Many
    ].freeze
    # :startdoc:

    def self.wrap(sources) # :nodoc:
      case sources
      when nil then []
      when Hash then sources.values.flat_map { |group| wrap(group) }
      else
        Utils.to_safe_array(sources).filter_map do |source|
          next if source.nil? || (source.is_a?(String) && source.strip.empty?)

          source.is_a?(Attachment) ? source : new(source)
        end
      end
    end

    # Creates an attachment from +source+: a file path, URL, IO-like object,
    # ActiveStorage object, or UploadedFile. Derives the filename from the
    # source when +filename:+ is not given, then detects the MIME type.
    #
    #   RubyLLM::Attachment.new("diagram.png")
    #   RubyLLM::Attachment.new(StringIO.new(data), filename: "report.pdf")
    #
    def initialize(source, filename: nil)
      @source = source
      @source = source_type_cast
      @filename = filename || source_filename

      determine_mime_type
    end

    def url? # :nodoc:
      @source.is_a?(URI) || (@source.is_a?(String) && @source.match?(%r{^https?://}))
    end

    def provider_file? # :nodoc:
      @source.is_a?(UploadedFile)
    end

    def provider_file_id # :nodoc:
      @source.id if provider_file?
    end

    def provider_file_uri # :nodoc:
      @source.uri if provider_file?
    end

    def path? # :nodoc:
      !provider_file? && (@source.is_a?(Pathname) || (@source.is_a?(String) && !url?))
    end

    def io_like? # :nodoc:
      @source.respond_to?(:read) && !path? && !active_storage? && !provider_file?
    end

    def active_storage? # :nodoc:
      ACTIVE_STORAGE_CLASS_NAMES.any? { |class_name| source_is_a?(class_name) }
    end

    # Returns the raw bytes of the attachment, fetching or reading the source
    # on the first call. Text content is returned as UTF-8.
    #
    # Raises RubyLLM::Error if the attachment is a provider-managed file,
    # which has no local content.
    def content
      if provider_file?
        raise Error, "Provider-managed file #{provider_file_id} cannot be read as inline attachment content"
      end

      load_content if !defined?(@content) || @content.nil?
      normalize_text_encoding
      @content
    end

    def encoded # :nodoc:
      Base64.strict_encode64(content)
    end

    def for_llm # :nodoc:
      case type
      when :text
        "<file name='#{filename}' mime_type='#{mime_type}'>#{content}</file>"
      else
        "data:#{mime_type};base64,#{encoded}"
      end
    end

    # Returns the attachment category as a Symbol: +:image+, +:video+,
    # +:audio+, +:pdf+, +:text+, +:document+, or +:unknown+.
    def type
      return :image if image?
      return :video if video?
      return :audio if audio?
      return :pdf if pdf?
      return :text if text?
      return :document if document?

      :unknown
    end

    # Returns whether the attachment is an image.
    def image?
      RubyLLM::MimeType.image? mime_type
    end

    # Returns whether the attachment is a video.
    def video?
      RubyLLM::MimeType.video? mime_type
    end

    # Returns whether the attachment is audio.
    def audio?
      RubyLLM::MimeType.audio? mime_type
    end

    def format # :nodoc:
      case mime_type
      when 'audio/mpeg'
        'mp3'
      when 'audio/wav', 'audio/wave', 'audio/x-wav'
        'wav'
      else
        mime_type.split('/').last
      end
    end

    # Returns whether the attachment is a PDF.
    def pdf?
      RubyLLM::MimeType.pdf? mime_type
    end

    # Returns whether the attachment is a non-PDF, non-text document format
    # such as Word or Excel, judged by MIME type or file extension.
    def document?
      return false if pdf? || text?

      RubyLLM::MimeType.document?(mime_type) || DOCUMENT_EXTENSIONS.include?(extension)
    end

    def extension # :nodoc:
      extension = File.extname(filename.to_s).delete_prefix('.').downcase
      extension.empty? ? nil : extension
    end

    # Returns whether the attachment is textual, like source code or CSV.
    def text?
      RubyLLM::MimeType.text? mime_type
    end

    def to_h # :nodoc:
      { type: type, source: @source }
    end

    def byte_size # :nodoc:
      file_byte_size || loaded_byte_size || content_byte_size
    end

    private

    def file_byte_size
      return @source.byte_size if provider_file?
      return File.size(@source) if path?

      active_storage_byte_size || io_byte_size
    end

    def active_storage_byte_size
      blob = active_storage_blob
      blob.byte_size if blob.respond_to?(:byte_size)
    end

    def io_byte_size
      return unless io_like?

      return @source.size if @source.respond_to?(:size)

      @source.stat.size if @source.respond_to?(:stat) && @source.stat.respond_to?(:size)
    end

    def loaded_byte_size
      @content.bytesize if defined?(@content) && @content
    end

    def content_byte_size
      return nil if url?

      content&.bytesize
    end

    def load_content
      if url?
        fetch_content
      elsif path?
        load_content_from_path
      elsif active_storage?
        load_content_from_active_storage
      elsif io_like?
        load_content_from_io
      else
        RubyLLM.logger.warn "Source is neither a URL, path, ActiveStorage, nor IO-like: #{@source.class}"
        nil
      end
    end

    # Text content is loaded as binary; retag it so payloads serialize as UTF-8.
    def normalize_text_encoding
      return unless text? && @content.is_a?(String) && @content.encoding == Encoding::ASCII_8BIT

      text = @content.dup.force_encoding(Encoding::UTF_8)
      @content = text.valid_encoding? ? text : text.scrub
    end

    def determine_mime_type
      return @mime_type = provider_file_mime_type if provider_file? && provider_file_mime_type

      content_type = active_storage? ? active_storage_content_type : nil
      return @mime_type = content_type unless content_type.to_s.empty?

      @mime_type = RubyLLM::MimeType.for(url? ? nil : @source, name: @filename)
      @mime_type = RubyLLM::MimeType.for(content) if @mime_type == 'application/octet-stream'
      @mime_type = 'audio/wav' if @mime_type == 'audio/x-wav' # Normalize WAV type
    end

    def fetch_content
      response = Connection.basic.get @source.to_s
      @content = response.body
    end

    def load_content_from_path
      @content = File.binread(@source)
    end

    def load_content_from_io
      @source.rewind if @source.respond_to? :rewind
      @content = @source.read
    end

    def load_content_from_active_storage
      @content = active_storage_blob&.download
    end

    def source_type_cast
      if url?
        URI(@source)
      elsif path?
        Pathname.new(@source)
      else
        @source
      end
    end

    def source_filename
      if url?
        File.basename(@source.path).to_s
      elsif provider_file?
        @source.filename.to_s
      elsif path?
        @source.basename.to_s
      elsif io_like?
        extract_filename_from_io
      elsif active_storage?
        extract_filename_from_active_storage
      end
    end

    def extract_filename_from_io
      if defined?(ActionDispatch::Http::UploadedFile) && @source.is_a?(ActionDispatch::Http::UploadedFile)
        @source.original_filename.to_s
      elsif @source.respond_to?(:path)
        File.basename(@source.path).to_s
      else
        'attachment'
      end
    end

    def extract_filename_from_active_storage
      active_storage_blob&.filename&.to_s || 'attachment'
    end

    def active_storage_content_type
      active_storage_blob&.content_type
    end

    def provider_file_mime_type
      @source.mime_type || RubyLLM::MimeType.for(nil, name: @source.filename)
    end

    def active_storage_blob
      return @source if source_is_a?('ActiveStorage::Blob')
      return @source.blob if source_is_a?('ActiveStorage::Attachment')
      return @source.blob if source_is_a?('ActiveStorage::Attached::One')

      @source.blobs.first if source_is_a?('ActiveStorage::Attached::Many')
    end

    def source_is_a?(class_name)
      klass = RubyLLM::Utils.safe_constantize(class_name)
      klass ? @source.is_a?(klass) : false
    end
  end
end
