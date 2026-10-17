# frozen_string_literal: true

require 'stringio'

module RubyLLM
  class FileStore
    module Converters
      # Reads the text layer of a PDF, page by page, with the pdf-reader
      # gem when the application bundles it. Returns +nil+ without the gem,
      # and for scans, which have no text layer.
      module PDF # :nodoc:
        module_function

        def call(attachment)
          return unless available?

          texts = ::PDF::Reader.new(StringIO.new(attachment.content.to_s.b)).pages.map { |page| page.text.to_s.strip }
          return if texts.all?(&:empty?)

          texts.each_with_index.map { |text, index| "## Page #{index + 1}\n\n#{text}" }.join("\n\n")
        rescue StandardError => e
          RubyLLM.logger.debug { "Could not read the text of a PDF: #{e.class}" }
          nil
        end

        def available?
          return @available unless @available.nil?

          @available = begin
            require 'pdf-reader'
            true
          rescue LoadError
            false
          end
        end
      end
    end
  end
end
