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
    # The OCR converter reads PDFs, scans, and photos with RubyLLM.ocr. It
    # costs a request per file, so it only runs where you register it.
    # Converters::Text reads a file as it is, for other types that hold
    # plain text.
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
        def convert(attachment, config: RubyLLM.config) # :nodoc:
          for_type(attachment.mime_type, config:).each do |converter|
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

        private

        def matches?(pattern, type)
          return true if pattern == '*/*'
          return type.start_with?(pattern.delete_suffix('*')) if pattern.end_with?('/*')

          pattern == type
        end

        def built_in(type)
          Files::MimeType.text?(type) ? [Text] : []
        end
      end
    end
  end
end
