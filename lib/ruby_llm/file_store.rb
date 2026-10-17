# frozen_string_literal: true

require 'digest'
require 'stringio'

module RubyLLM
  # A FileStore keeps a chat's files: what people attach, what tools
  # return, long tool results, and what code writes. Chat#with_file_store gives
  # a chat one, and the model works with it through five tools that list,
  # read, search, write, and edit its files, so a file reaches the model
  # only when the model asks for it.
  #
  #   chat = RubyLLM.chat.with_file_store
  #   chat.ask "Which clauses changed?", with: ["contract-v1.pdf", "contract-v2.pdf"]
  #   chat.file_store.list.map(&:path) # => ["contract-v1.pdf", "contract-v2.pdf"]
  #
  # RubyLLM ships FileStore::Memory, the default, and FileStore::Directory,
  # which keeps the files in a folder; RubyLLM.file_store builds them. The
  # Rails integration keeps a persisted chat's files in Active Storage.
  #
  #   chat.with_file_store(RubyLLM.file_store.directory("tmp/work"))
  #
  # Write your own store by subclassing FileStore and implementing #list,
  # #find, #read, #write, and #delete. RubyLLM only ever passes them paths
  # FileStore.path accepts: relative, with forward slashes, and without
  # empty, <tt>.</tt>, or <tt>..</tt> parts.
  #
  #   class BucketStore < RubyLLM::FileStore
  #     def initialize(bucket, prefix)
  #       super()
  #       @bucket = bucket
  #       @prefix = prefix
  #     end
  #
  #     def list(prefix = nil) = ...
  #     def find(path) = ...
  #     def read(path) = ...
  #     def write(path, content, content_type: nil) = ...
  #     def delete(path) = ...
  #   end
  class FileStore
    include Enumerable

    # Converted texts each store keeps in memory, by default.
    CACHED_TEXTS = 100

    UNSAFE_CHARACTERS = /[\x00-\x1f\x7f\\:*?"<>|]/
    private_constant :UNSAFE_CHARACTERS

    class << self
      # Returns +name+ as a path inside a store: relative, with forward
      # slashes, and with a leading <tt>./</tt> or <tt>/</tt> and repeated
      # slashes removed.
      #
      #   RubyLLM::FileStore.path("./reports//q3.pdf") # => "reports/q3.pdf"
      #
      # Raises ArgumentError for an empty path or one with <tt>.</tt> or
      # <tt>..</tt> parts.
      def path(name)
        parts = name.to_s.tr('\\', '/').split('/').reject(&:empty?)
        parts.shift while parts.first == '.'
        if parts.empty? || parts.intersect?(%w[. ..]) || parts.any? { |part| part.match?(/[\x00-\x1f]/) }
          raise ArgumentError, "#{name.inspect} is not a path inside the chat's files"
        end

        parts.join('/')
      end

      # Returns whether +path+ is inside the folder +prefix+, or is it.
      # Every path is inside a +nil+ or empty prefix.
      def inside?(path, prefix) # :nodoc:
        return true if prefix.to_s.empty?

        folder = path(prefix)
        path == folder || path.start_with?("#{folder}/")
      end

      # Returns a safe file name for an attachment called +name+.
      def filename(name) # :nodoc:
        base = File.basename(name.to_s.tr('\\', '/')).gsub(UNSAFE_CHARACTERS, '_').strip
        ['', '.', '..'].include?(base) ? 'file' : base
      end

      # Returns the SHA-256 of +content+ in hex.
      def digest(content) # :nodoc:
        Digest::SHA256.hexdigest(content)
      end

      # Returns the MIME type of +content+ written to +path+.
      def content_type_for(path, content) # :nodoc:
        type = Files::MimeType.for(name: File.basename(path))
        type = Files::MimeType.for(StringIO.new(content)) if type == 'application/octet-stream' && !content.empty?
        type
      end

      # Returns the bytes of +content+, a String or an IO.
      def bytes(content) # :nodoc:
        content = content.read if content.respond_to?(:read)
        content.to_s.b
      end
    end

    def initialize # :nodoc:
      @texts = {}
      @texts_lock = Mutex.new
    end

    # Returns the files inside the folder +prefix+, or every file, as
    # StoredFile objects sorted by path.
    #
    #   chat.file_store.list("reports")
    def list(prefix = nil)
      raise NotImplementedError, "#{self.class} must implement list"
    end

    # Returns the StoredFile at +path+, or +nil+.
    def find(path)
      raise NotImplementedError, "#{self.class} must implement find"
    end

    # Returns the content of the file at +path+ as a binary String.
    # Raises FileNotFoundError when there is none.
    def read(path)
      raise NotImplementedError, "#{self.class} must implement read"
    end

    # Writes +content+, a String or an IO, to +path+, replacing any file
    # there, and returns its StoredFile. The content type is detected from
    # the path and the content unless given.
    #
    #   chat.file_store.write("notes/plan.md", "# Plan")
    def write(path, content, content_type: nil)
      raise NotImplementedError, "#{self.class} must implement write"
    end

    # Deletes the file at +path+ and returns its StoredFile, or +nil+ when
    # there was none.
    def delete(path)
      raise NotImplementedError, "#{self.class} must implement delete"
    end

    # Yields each StoredFile, as #list returns them.
    def each(&)
      list.each(&)
    end

    # Returns whether there is a file at +path+.
    def exists?(path)
      !find(path).nil?
    end

    # Returns the text of the file at +path+: its content when it is text,
    # or what a converter makes of it, such as the text of a PDF or a Word
    # document. Returns +nil+ when no converter can read the file.
    # Conversions are kept, so each version of a file is converted once.
    # Raises FileNotFoundError when there is no file at +path+.
    #
    #   chat.file_store.text("contract.pdf") # => "## Page 1\n\nThis agreement..."
    #
    # See Configuration#file_converters for adding converters.
    def text(path, config: nil)
      file = find(path) || raise(FileNotFoundError, "No file at #{path}")
      cached = cached_text(file)
      return cached if cached

      Converters.convert(attachment(file.path, file:), config: config || RubyLLM.config).tap do |text|
        cache_text(file, text) if text
      end
    end

    # Returns the file at +path+ as an Attachment, to send it to a model.
    # Raises FileNotFoundError when there is none.
    def attachment(path, file: nil)
      file ||= find(path) || raise(FileNotFoundError, "No file at #{path}")
      Attachment.new(StringIO.new(read(file.path)), filename: file.filename)
    end

    # Returns the converted text kept for +file+, or +nil+. Stores keep
    # conversions in memory unless they override this and #cache_text.
    def cached_text(file)
      @texts_lock.synchronize { @texts[text_key(file)] }
    end

    # Keeps +text+ as the conversion of +file+.
    def cache_text(file, text)
      @texts_lock.synchronize do
        @texts.delete(@texts.keys.first) if @texts.size >= CACHED_TEXTS
        @texts[text_key(file)] = text
      end
    end

    # Writes +attachment+ under its file name and returns its StoredFile,
    # yielding it when it is new. A file already there with the same
    # content is reused; one with other content keeps its place, and the
    # attachment gets a numbered name beside it, such as
    # <tt>report-2.pdf</tt>.
    def store_attachment(attachment) # :nodoc:
      content = attachment.content.to_s.b
      digest = self.class.digest(content)
      candidates(self.class.filename(attachment.filename)).each do |path|
        existing = find(path)
        return existing if existing && same_content?(existing, content, digest)
        next if existing

        file = write_attachment(path, attachment, content)
        yield file if block_given?
        return file
      end
    end

    private

    def write_attachment(path, attachment, content)
      write(path, content, content_type: attachment.mime_type)
    end

    def candidates(name)
      extension = File.extname(name)
      base = name.delete_suffix(extension)
      Enumerator.new do |paths|
        paths << name
        (2..).each { |number| paths << "#{base}-#{number}#{extension}" }
      end
    end

    def same_content?(file, content, digest)
      file.digest ? file.digest == digest : read(file.path).b == content
    end

    def text_key(file)
      file.digest || [file.path, file.byte_size, file.updated_at]
    end
  end
end
