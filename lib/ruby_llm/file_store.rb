# frozen_string_literal: true

require 'digest'
require 'monitor'
require 'stringio'

module RubyLLM
  # A FileStore keeps a chat's files: what people attach, what tools
  # return, long tool results, and what code writes. Chat#with_file_store gives
  # a chat one, and the model works with it through tools that list, read,
  # search, write, and edit its files, so a file reaches the model only
  # when the model asks for it.
  #
  #   chat = RubyLLM.chat.with_file_store
  #   chat.ask "Which clauses changed?", with: ["contract-v1.pdf", "contract-v2.pdf"]
  #   chat.file_store.list.map(&:path) # => ["contract-v1.pdf", "contract-v2.pdf"]
  #
  # RubyLLM ships FileStore::Memory, the default, and FileStore::Directory,
  # which keeps the files in a folder. The Rails integration keeps a
  # persisted chat's files in Active Storage.
  #
  #   chat.with_file_store("tmp/work")
  #
  # Write your own store by subclassing FileStore and implementing #list,
  # #[], #read, #write, and #delete. RubyLLM only ever passes them paths
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
  #     def [](path) = ...
  #     def read(path) = ...
  #     def write(path, content, content_type: nil) = ...
  #     def delete(path) = ...
  #   end
  #
  # The model must read a file before its tools change it, and a file that
  # changed since it read it must be read again. The store remembers what
  # the model read, and #with_lock keeps two changes to the files from
  # interleaving. Override #with_lock in a store that several processes
  # share.
  class FileStore
    include Enumerable

    # Raised by #delete for a path that is a folder.
    class FolderError < ArgumentError; end # :nodoc:

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

      # Returns whether +path+ matches the glob +pattern+. A pattern
      # without a slash matches the file name in any folder; one with a
      # slash matches the whole path, or the path inside the folder
      # +inside+. <tt>**</tt> matches any number of folders, a trailing
      # <tt>/**</tt> everything under a folder, and <tt>{a,b}</tt> either.
      def match?(path, pattern, inside: nil) # :nodoc:
        pattern = pattern.to_s.delete_prefix('./').delete_prefix('/')
        flags = File::FNM_PATHNAME | File::FNM_EXTGLOB
        return File.fnmatch?(pattern, File.basename(path), flags) unless pattern.include?('/')

        pattern = "#{pattern}/*" if pattern.end_with?('/**')
        candidates = [path]
        candidates << path.delete_prefix("#{inside}/") unless inside.to_s.empty?
        candidates.any? { |candidate| File.fnmatch?(pattern, candidate, flags) }
      end

      # Returns a safe file name for an attachment called +name+.
      def filename(name) # :nodoc:
        base = File.basename(name.to_s.tr('\\', '/')).gsub(UNSAFE_CHARACTERS, '_').strip.sub(/\A\.+/, '')
        base.empty? ? 'file' : base
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
      @reads = {}
      @reads_lock = Mutex.new
      @store_lock = Monitor.new
    end

    # Returns the files inside the folder +prefix+, or every file, as
    # StoredFile objects sorted by path.
    #
    #   chat.file_store.list("reports")
    def list(prefix = nil)
      raise NotImplementedError, "#{self.class} must implement list"
    end

    # Returns the StoredFile at +path+, or +nil+ when there is none.
    #
    #   chat.file_store["notes/plan.md"] # => #<RubyLLM::StoredFile path: "notes/plan.md", ...>
    def [](path)
      raise NotImplementedError, "#{self.class} must implement []"
    end

    # Returns the StoredFile at +path+. Raises FileNotFoundError when there
    # is none.
    #
    #   chat.file_store.find("notes/plan.md")
    def find(path)
      self[path] || raise(FileNotFoundError, "No file at #{FileStore.path(path)}")
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
    # there was none. Raises ArgumentError when +path+ is a folder.
    #
    #   chat.file_store.delete("notes/plan.md")
    def delete(path)
      raise NotImplementedError, "#{self.class} must implement delete"
    end

    # Deletes everything inside the folder +path+ and returns the deleted
    # StoredFile objects, sorted by path. Raises ArgumentError when +path+
    # is a file.
    #
    #   chat.file_store.delete_folder("reports") # => [#<RubyLLM::StoredFile path: "reports/q3.pdf", ...>]
    def delete_folder(path)
      path = FileStore.path(path)
      refuse_file(path) if self[path]

      list(path).filter_map { |file| delete(file.path) }
    end

    # Returns the folder on disk that holds the files, or +nil+. A store
    # with one has code execution run in that folder, reading and writing
    # the files in place; a store without one has each run read the
    # attachments in +attachments/+ and copy in the files it names.
    # FileStore::Directory returns its root.
    def local_root # :nodoc:
      nil
    end

    # Yields each StoredFile, as #list returns them.
    def each(&)
      list.each(&)
    end

    # Returns whether there is a file at +path+.
    def exist?(path)
      !self[path].nil?
    end

    # Returns the digest of the content the model last read at +path+, or
    # +nil+ when it has not read it. The file tools compare it with the
    # file's digest before they change the file.
    def read_digest(path) # :nodoc:
      @reads_lock.synchronize { @reads[FileStore.path(path)] }
    end

    # Remembers that the model read +digest+, a digest of the content, at
    # +path+, in memory.
    def record_read(path, digest) # :nodoc:
      @reads_lock.synchronize { @reads[FileStore.path(path)] = digest }
    end

    # Runs the block with the store locked and returns its value, so a tool
    # that reads a file and writes it back sees no other change in
    # between. It is reentrant. Stores lock within this process unless
    # they override it.
    def with_lock(&)
      @store_lock.synchronize(&)
    end

    # Returns the text of the file at +path+: its content when it is text,
    # or what a converter makes of it, such as the text OCR reads from a
    # PDF. Returns +nil+ when no converter can read the file.
    # Conversions are kept, so each version of a file is converted once.
    # Raises FileNotFoundError when there is no file at +path+.
    #
    #   chat.file_store.text("contract.pdf") # => "## Page 1\n\nThis agreement..."
    #
    # See Configuration#file_converters for adding converters.
    def text(path, config: nil)
      file = find(path)
      cached = cached_text(file)
      return cached if cached

      Converters.convert(attachment(file.path, file:), config: config || RubyLLM.config).tap do |text|
        cache_text(file, text) if text
      end
    end

    # Returns the file at +path+ as an Attachment, to send it to a model.
    # Raises FileNotFoundError when there is none.
    def attachment(path, file: nil)
      file ||= find(path)
      Attachment.new(StringIO.new(read(file.path)), filename: file.filename)
    end

    # Returns the converted text kept for +file+, or +nil+, from memory.
    def cached_text(file) # :nodoc:
      @texts_lock.synchronize { @texts[text_key(file)] }
    end

    # Keeps +text+ as the conversion of +file+, in memory.
    def cache_text(file, text) # :nodoc:
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
        existing = self[path]
        return existing if existing && same_content?(existing, content, digest)
        next if existing || folder?(path)

        file = write_attachment(path, attachment, content)
        yield file if block_given?
        return file
      end
    end

    private

    def folder?(_path)
      false
    end

    def refuse_folder(path)
      raise FolderError, "#{path} is a folder: delete it with delete_folder"
    end

    def refuse_file(path)
      raise ArgumentError, "#{path} is a file: delete it with delete"
    end

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
