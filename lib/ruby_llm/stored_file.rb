# frozen_string_literal: true

module RubyLLM
  # A file in a FileStore: its path, size, content type, and a digest of
  # its content. FileStore#list and FileStore#find return them, and
  # Chat#after_file_write callbacks receive each one the conversation
  # writes.
  #
  #   chat.files.list
  #   # => [#<RubyLLM::StoredFile path: "report.pdf", byte_size: 2201344, content_type: "application/pdf">]
  #
  class StoredFile
    include Support::Inspectable

    # The path of the file inside its store, relative and with forward
    # slashes, such as <tt>"reports/q3.pdf"</tt>.
    attr_reader :path

    # The size of the file in bytes.
    attr_reader :byte_size

    # The MIME type of the file, such as <tt>"application/pdf"</tt>.
    attr_reader :content_type

    # A digest of the file's content that changes whenever the content
    # does, or +nil+ when the store does not know one without reading the
    # file. Stores in the box use SHA-256 in hex.
    attr_reader :digest

    # When the file was last written, or +nil+ when the store does not say.
    attr_reader :updated_at

    # Who wrote the file, for stores that keep one, or +nil+. RubyLLM
    # stores it and hands it back without interpreting it.
    attr_reader :owner

    def initialize(path:, byte_size:, content_type:, digest: nil, updated_at: nil, owner: nil) # :nodoc:
      @path = path
      @byte_size = byte_size
      @content_type = content_type
      @digest = digest
      @updated_at = updated_at
      @owner = owner
    end

    # Returns the last part of #path.
    #
    #   file.path     # => "reports/q3.pdf"
    #   file.filename # => "q3.pdf"
    #
    def filename
      File.basename(path)
    end

    # Returns whether the content is text, like source code, CSV, or
    # Markdown, judged by its content type.
    def text?
      Files::MimeType.text?(content_type)
    end

    # Returns the file's size for people and models to read, such as
    # <tt>"2.1 MB"</tt>.
    def human_size
      units = %w[bytes KB MB GB TB]
      size = byte_size.to_f
      exponent = size.zero? ? 0 : [(Math.log(size) / Math.log(1024)).floor, units.size - 1].min
      return "#{byte_size} #{byte_size == 1 ? 'byte' : 'bytes'}" if exponent.zero?

      "#{(size / (1024**exponent)).round(1)} #{units[exponent]}"
    end

    # Returns whether +other+ is a StoredFile with the same path, size,
    # content type, and digest.
    def ==(other)
      other.is_a?(StoredFile) && other.to_h.except(:updated_at, :owner) == to_h.except(:updated_at, :owner)
    end
    alias eql? ==

    def hash # :nodoc:
      to_h.except(:updated_at, :owner).hash
    end

    # Returns the attributes as a Hash.
    def to_h
      { path:, byte_size:, content_type:, digest:, updated_at:, owner: }
    end

    private

    def inspect_attributes
      { path:, byte_size:, content_type: }
    end
  end
end
