# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Returns the converters RubyLLM ships, so registering one needs no
      # class names. <tt>RubyLLM.file_store.converter</tt> returns it.
      #
      #   config.file_converters["image/*"] = RubyLLM.file_store.converter.ocr
      #   config.file_converters["application/x-subrip"] = RubyLLM.file_store.converter.text
      #
      # Text files are read without registering anything; register +text+
      # for other types that hold plain text. For a converter of your own,
      # register anything that answers +call+ (see Converters).
      module Factory
        module_function

        # Returns a converter that reads PDFs, scans, and photos with
        # RubyLLM.ocr, passing +options+ such as +model:+, +provider:+, or
        # +context:+. See Converters::OCR.
        def ocr(**)
          OCR.new(**)
        end

        # Returns the converter that reads a file as UTF-8 text, as it is.
        def text
          Text
        end
      end
    end
  end
end
