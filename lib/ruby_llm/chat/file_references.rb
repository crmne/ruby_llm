# frozen_string_literal: true

require 'json'
require 'stringio'

module RubyLLM
  class Chat
    # What Chat#with_files changes in a conversation. Every attachment is
    # kept in the chat's FileStore, and each request shows it in full only
    # while it is new: on the latest question, and on read_file results
    # since then. Before that, and on other tools' results, the model sees
    # one line naming the file, and reads it again with the file tools. A
    # tool result longer than the spill-over limit is saved as a file, and
    # the model gets its start and the path. An attachment the provider
    # cannot take, such as a Word file, becomes that line too.
    class FileReferences # :nodoc:
      OPTIONS = %i[store spill_over].freeze
      SPILL_OVER = 10_000
      PREVIEW = 2_000
      READ_TOOL = 'read_file'

      attr_reader :spill_over, :store

      class << self
        def options(enabled, options, store_lambda: false)
          return options(true, enabled.transform_keys(&:to_sym).merge(options), store_lambda:) if enabled.is_a?(Hash)
          raise ArgumentError, 'with_files accepts true, false, or file options' unless [true, false].include?(enabled)
          raise ArgumentError, 'with_files(false) does not accept options' if !enabled && options.any?
          return false unless enabled

          validate(options, store_lambda:)
          options.freeze
        end

        private

        def validate(options, store_lambda:)
          unknown = options.keys - OPTIONS
          raise ArgumentError, "with_files accepts #{OPTIONS.join(', ')}, got #{unknown.join(', ')}" if unknown.any?

          validate_store(options[:store], store_lambda:)
          spill_over = options.fetch(:spill_over, SPILL_OVER)
          return if spill_over == false || (spill_over.is_a?(Integer) && spill_over.positive?)

          raise ArgumentError, 'spill_over: takes a positive number of characters or false'
        end

        def validate_store(store, store_lambda:)
          return if store.nil? || store.is_a?(FileStore) || (store_lambda && store.is_a?(Proc))

          raise ArgumentError, "store: takes a RubyLLM::FileStore, got #{store.inspect}"
        end
      end

      def initialize(store:, spill_over:, written:)
        @store = store
        @spill_over = spill_over
        @written = written
        @stored = {}.compare_by_identity
      end

      def view(list)
        current = list.rindex { |message| message.role == :user } || 0
        reads = read_call_ids(list)
        list.each_with_index.map do |message, index|
          message.attachments.empty? ? message : view_message(message, current: index >= current, reads:)
        end
      end

      def spill(tool, tool_call, content)
        limit = tool.respond_to?(:spill_over) ? tool.spill_over : nil
        limit = @spill_over if limit.nil?
        return content unless limit && content.is_a?(String) && content.length > limit

        text, extension = readable(content)
        file = write("results/#{tool_call.name}-#{safe_id(tool_call.id)}.#{extension}", text)
        "#{text[0, PREVIEW]}\n\n[This result has #{text.length} characters, so only the start is shown. " \
          "All of it is in #{file.path}: read more with read_file, or search it with search_files.]"
      end

      def store_attachment(attachment)
        @stored[attachment] ||= store.store_attachment(attachment) { |file| @written.call(file) }
      end

      def describe(attachment)
        file = store_attachment(attachment)
        reference(file.path, file)
      end

      private

      def view_message(message, current:, reads:)
        read = message.tool_result? && reads.include?(message.tool_call_id)
        shown = current && (!message.tool_result? || read)
        attachments = message.attachments.map { |attachment| view_of(attachment, shown:, read:) }
        shown ? message : message.with_attachments(attachments)
      end

      def view_of(attachment, shown:, read:)
        return attachment if attachment.provider_file?
        return (shown ? attachment : reference(attachment.filename, nil)) if read

        file = store_attachment(attachment)
        shown ? attachment : reference(file.path, file)
      rescue StandardError => e
        RubyLLM.logger.warn { "Could not keep an attachment in the chat's files: #{e.class}" }
        attachment
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

      def read_call_ids(list)
        list.flat_map { |message| (message.tool_calls || {}).values }
            .select { |call| call.name == READ_TOOL }.to_set(&:id)
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

      def safe_id(id)
        id.to_s.gsub(/[^A-Za-z0-9]/, '').chars.last(8).join
      end
    end
  end
end
