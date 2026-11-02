# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads a file as UTF-8 text, as it is. Text files are read without
      # registering anything; register it for other types that hold plain
      # text:
      #
      #   config.file_converters["application/x-subrip"] = RubyLLM::FileStore::Converters::Text
      #
      module Text
        module_function

        # Returns the content of +attachment+ as UTF-8 text.
        def call(attachment)
          attachment.content.to_s.dup.force_encoding(Encoding::UTF_8).scrub
        end
      end
    end
  end
end
