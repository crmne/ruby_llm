# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads scans, photos, and PDFs with RubyLLM.ocr. Each file costs one
      # OCR request the first time the model reads or searches it, and is
      # kept after that. Register it in Configuration#file_converters for
      # the types it should read:
      #
      #   config.file_converters = {
      #     "image/*" => RubyLLM::FileStore::Converters::OCR.new,
      #     "application/pdf" => RubyLLM::FileStore::Converters::OCR.new(model: "mistral-ocr-latest")
      #   }
      #
      class OCR
        # Creates a converter that calls RubyLLM.ocr with +options+, such as
        # +model:+, +provider:+, or +context:+.
        def initialize(**options)
          @options = options
        end

        # Returns the Markdown RubyLLM.ocr reads from +attachment+.
        def call(attachment)
          RubyLLM.ocr(attachment, **@options).markdown
        end
      end
    end
  end
end
