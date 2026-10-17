# frozen_string_literal: true

module RubyLLM
  class FileStore
    # Converters turn files into text the model can read and search. A
    # converter is any object that answers +call+ with an Attachment and
    # returns the file's text, or +nil+ when it cannot read that file, so
    # the next converter gets a turn. FileStore#text tries the converters
    # in Configuration#file_converters first, then the ones RubyLLM ships:
    #
    # * text files, including source code, CSV, JSON, and Markdown, as they are
    # * HTML, without its tags
    # * Word, Excel, and PowerPoint files (+.docx+, +.xlsx+, +.pptx+)
    # * PDFs, with the pdf-reader gem in your bundle
    #
    # The OCR converter reads scans and photos with RubyLLM.ocr. It costs
    # a request per file, so it only runs where you register it.
    # RubyLLM.file_store.converter returns the converters RubyLLM ships
    # (see Converters::Factory):
    #
    #   RubyLLM.configure do |config|
    #     config.file_converters["image/*"] = RubyLLM.file_store.converter.ocr
    #     config.file_converters["application/pdf"] = RubyLLM.file_store.converter.ocr
    #     config.file_converters["application/vnd.oasis.opendocument.text"] = ->(file) { OdtText.call(file.content) }
    #   end
    #
    # A PDF with a text layer is read by the built-in converter only when
    # yours returns +nil+, so register OCR after your own converters, or
    # as the only one for scans.
    module Converters
      OFFICE_TYPES = [
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation'
      ].freeze
      private_constant :OFFICE_TYPES

      class << self
        # Returns the text the first converter for +attachment+ makes of it,
        # or +nil+ when none can read it.
        def convert(attachment, config: RubyLLM.config) # :nodoc:
          for_type(attachment.mime_type, config:).each do |converter|
            text = converter.call(attachment)
            return text.dup.force_encoding(Encoding::UTF_8).scrub if text.is_a?(String) && !text.strip.empty?
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
          return [HTML] if type == 'text/html' || type.end_with?('+html')
          return [Text] if Files::MimeType.text?(type)
          return [Office] if OFFICE_TYPES.include?(type)
          return [PDF] if Files::MimeType.pdf?(type)

          []
        end
      end
    end
  end
end
