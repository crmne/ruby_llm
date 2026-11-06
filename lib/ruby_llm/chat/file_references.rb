# frozen_string_literal: true

require 'json'
require 'stringio'

module RubyLLM
  class Chat
    # What Chat#with_file_store changes in a conversation. Every attachment is
    # kept in the chat's FileStore, and each request shows it in full only
    # while it is new: on the latest question, and on read_file results
    # since then. Before that, and on other tools' results, the model sees
    # one line naming the file, and reads it again with the file tools. A
    # tool result longer than the inline limit is saved as a file, and
    # the model gets its start and the path. An attachment the provider
    # cannot take, such as a Word file, goes as the text the store's
    # converters read from it, or as that line when none can. An attachment
    # a converter on this machine reads for free has its text extracted
    # when it is kept, so search_files finds it at once.
    class FileReferences # :nodoc:
      INLINE_LIMIT = 10_000
      PREVIEW = 2_000
      READ_TOOL = 'read_file'

      # Stands for the store a chat picks when given none: a new
      # FileStore::Memory, or a persisted chat's files in Active Storage.
      DEFAULT_STORE = Object.new.tap { |default| def default.inspect = 'the default store' }.freeze

      attr_reader :inline_limit, :tools, :store

      class << self
        def validate(store, inline_limit:, tools: FileStore::Tools::DEFAULT, store_lambda: false)
          unless store?(store) || (store_lambda && store.is_a?(Proc))
            raise ArgumentError, 'with_file_store takes a folder path, :memory, a RubyLLM::FileStore, or nil, ' \
                                 "got #{store.inspect}"
          end
          FileStore::Tools.names(tools)
          return if inline_limit == false || (inline_limit.is_a?(Integer) && inline_limit.positive?)

          raise ArgumentError, 'inline_limit: takes a positive number of characters or false'
        end

        def resolve(store)
          return FileStore::Memory.new if store == :memory
          return FileStore::Directory.new(store) if path?(store)

          store
        end

        private

        def store?(store)
          store.is_a?(FileStore) || store.equal?(DEFAULT_STORE) || store == :memory || path?(store)
        end

        def path?(store)
          store.is_a?(String) || store.respond_to?(:to_path)
        end
      end

      def initialize(store:, inline_limit:, written:, tools: FileStore::Tools::DEFAULT, config: -> { RubyLLM.config })
        @store = store
        @config = config
        @inline_limit = inline_limit
        @tools = FileStore::Tools.names(tools)
        @written = written
        @stored = {}.compare_by_identity
        @described = {}.compare_by_identity
      end

      def view(list)
        current = list.rindex { |message| message.role == :user } || 0
        reads = read_paths(list)
        list.each_with_index.map do |message, index|
          message.attachments.empty? ? message : view_message(message, current: index >= current, reads:)
        end
      end

      def spill(tool, tool_call, content)
        limit = tool.respond_to?(:inline_limit) ? tool.inline_limit : nil
        limit = @inline_limit if limit.nil?
        return content unless limit && content.is_a?(String) && content.length > limit

        text, extension = readable(content)
        file = write("results/#{safe_name(tool_call.name)}-#{safe_id(tool_call.id)}.#{extension}", text)
        "#{text[0, PREVIEW]}\n\n[This result has #{text.length} characters, so only the start is shown. " \
          "All of it is in #{file.path}: read more with read_file, or search it with search_files.]"
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not save a long tool result in the chat's files: #{e.class}" }
        content
      end

      def store_attachment(attachment)
        @stored[attachment] ||= store.store_attachment(attachment) do |file|
          @written.call(file)
          extract(file)
        end
      end

      def describe(attachment, config: RubyLLM.config)
        file = store_attachment(attachment)
        (as_text(file, config) || reference(file.path, file)).tap { |replacement| @described[replacement] = true }
      end

      # Records a read for each text attachment in +list+, the messages a
      # request sent, that went as itself and matches the file in the store.
      # Anything else the provider got for it, a reference, converted text,
      # or an upload, is a new object that was never stored here.
      def record_shown(list)
        list.flat_map(&:attachments).each do |attachment|
          file = @stored[attachment]
          record_read(attachment, file) if file && attachment.text?
        end
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not record the files a request showed: #{e.class}" }
      end

      # Removes the replacements #describe made from +replacements+, a
      # chat's memo, so another store or limit describes them again.
      def forget(replacements)
        replacements.delete_if { |_attachment, replacement| @described.key?(replacement) }
      end

      private

      def record_read(attachment, file)
        seen = FileStore.digest(attachment.content.to_s.b)
        current = store[file.path]
        return unless current && seen == (current.digest || FileStore.digest(store.read(current.path)))

        store.record_read(current.path, seen) unless store.read_digest(current.path) == seen
      end

      def extract(file)
        return if file.text? || store.cached_text(file)

        text = FileStore::Converters.convert(store.attachment(file.path, file:), config: @config.call, local: true)
        store.cache_text(file, text) if text
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not extract the text of #{file.path}: #{e.class}" }
      end

      def view_message(message, current:, reads:)
        read = (reads[message.tool_call_id] if message.tool_result?)
        shown = current && (!message.tool_result? || read)
        attachments = message.attachments.map { |attachment| view_of(attachment, shown:, read:) }
        attachments == message.attachments ? message : message.with_attachments(attachments)
      end

      def view_of(attachment, shown:, read:)
        return attachment if attachment.provider_file?
        return (shown ? attachment : reference(read, nil)) if read

        file = store_attachment(attachment)
        return reference(file.path, file) unless shown

        too_long?(attachment) ? start_of(attachment, file) : attachment
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not keep an attachment in the chat's files: #{e.class}" }
        attachment
      end

      def too_long?(attachment)
        @inline_limit && attachment.text? && attachment.content.to_s.length > @inline_limit
      end

      def start_of(attachment, file)
        text_attachment(file, attachment.content.to_s)
      end

      def as_text(file, config)
        text = store.text(file.path, config:)
        return if text.nil? || text.strip.empty?

        text_attachment(file, text)
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not read #{file.path} as text: #{e.class}" }
        nil
      end

      def text_attachment(file, text)
        if @inline_limit && text.length > @inline_limit
          text = "#{text[0, @inline_limit]}\n\n[#{file.path} has #{text.length} characters, so only the start " \
                 'is shown, and you have not seen the rest. Read more with read_file, or search it with search_files.]'
        end
        Attachment.new(StringIO.new("#{file.path}, read as text:\n\n#{text}"),
                       filename: "#{File.basename(file.path)}.txt")
      end

      def reference(path, file)
        text = if file
                 "#{path} (#{file.content_type}, #{file.human_size}) is in this chat's files and not shown " \
                   'here. Open it with read_file, or search it with search_files.'
               else
                 "#{path} was shown here. Open it again with read_file to see it."
               end
        Attachment.new(StringIO.new(text), filename: "#{File.basename(path)}.txt")
      end

      # Returns the path each read_file call asked for, by call id.
      def read_paths(list)
        list.flat_map { |message| message.tool_calls.to_a }
            .select { |call| call.name == READ_TOOL }
            .to_h { |call| [call.id, read_path(call)] }
      end

      def read_path(call)
        path = call.arguments.to_h.transform_keys(&:to_s)['path'].to_s
        path.empty? ? 'the file' : path
      end

      def write(path, content)
        store.write(path, content).tap { |file| @written.call(file) }
      end

      def readable(content)
        return [content, 'txt'] unless content.lstrip.start_with?('{', '[')

        [JSON.pretty_generate(JSON.parse(content)), 'json']
      rescue JSON::ParserError
        [content, 'txt']
      end

      def safe_name(name)
        name.to_s.gsub(/[^A-Za-z0-9_-]/, '_')[0, 64]
      end

      def safe_id(id)
        id.to_s.gsub(/[^A-Za-z0-9]/, '').chars.last(8).join
      end
    end
  end
end
