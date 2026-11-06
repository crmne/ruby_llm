# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Converters turn files into text the model can read and search. A
    # converter is any object that answers +call+ with an Attachment and
    # returns the file's text, or +nil+ when it cannot read that file, so
    # the next converter gets a turn. FileStore#text tries the converters
    # in Configuration#file_converters first, then reads text files,
    # including source code, CSV, JSON, and Markdown, as they are.
    #
    # Converters::Office reads Word, Excel, and PowerPoint files without
    # any setup. The OCR converter reads PDFs, scans, and photos with
    # RubyLLM.ocr. It costs a request per file, so it only runs where you
    # register it. Converters::Text reads a file as it is, for other types
    # that hold plain text.
    #
    # A converter that answers +local?+ with +true+ reads files on this
    # machine for free, so a chat runs it as soon as it keeps an
    # attachment, while it prepares the request, so keep it fast, and
    # search_files finds the text without a read_file first. The others wait
    # for read_file, or for a request that must send as text a file the
    # provider cannot take.
    #
    #   RubyLLM.configure do |config|
    #     config.file_converters["image/*"] = RubyLLM::FileStore::Converters::OCR.new
    #     config.file_converters["application/pdf"] = RubyLLM::FileStore::Converters::OCR.new
    #     config.file_converters["application/x-subrip"] = RubyLLM::FileStore::Converters::Text
    #     config.file_converters["application/vnd.oasis.opendocument.text"] = ->(file) { OdtText.call(file.content) }
    #   end
    #
    # Converters for other formats can ship as gems named
    # <tt>ruby_llm-converters-NAME</tt>, like provider gems.
    module Converters
      class << self
        # Returns the text the first converter for +attachment+ makes of it,
        # or +nil+ when none can read it.
        # With <tt>local: true</tt>, stops at the first converter that does
        # not run on this machine for free, so one that may cost money, or
        # that was registered to go first, is never passed over.
        def convert(attachment, config: RubyLLM.config, local: false) # :nodoc:
          converters = for_type(attachment.mime_type, config:)
          converters = converters.take_while { |converter| local?(converter) } if local
          converters.each do |converter|
            text = converter.call(attachment)
            next unless text.is_a?(String)

            text = text.dup.force_encoding(Encoding::UTF_8).scrub
            return text unless text.strip.empty?
          end
          nil
        end

        # Returns the converters for files of +type+, in the order they are
        # tried.
        def for_type(type, config: RubyLLM.config) # :nodoc:
          configured = config.file_converters.to_h.select { |pattern, _| matches?(pattern.to_s, type) }
          configured.sort_by { |pattern, _| pattern.to_s.end_with?('*') ? 1 : 0 }
                    .flat_map { |_, converters| Array(converters) } + built_in(type)
        end

        # Returns whether +converter+ reads files on this machine for free.
        def local?(converter) # :nodoc:
          converter.respond_to?(:local?) && converter.local? == true
        end

        private

        def matches?(pattern, type)
          return true if pattern == '*/*'
          return type.start_with?(pattern.delete_suffix('*')) if pattern.end_with?('/*')

          pattern == type
        end

        def built_in(type)
          return [Text] if Files::MimeType.text?(type)

          Office::TYPES.key?(type) ? [Office] : []
        end
      end
    end
  end
end
