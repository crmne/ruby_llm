# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads text files as they are.
      module Text # :nodoc:
        module_function

        def call(attachment)
          attachment.content.to_s.dup.force_encoding(Encoding::UTF_8).scrub
        end
      end
    end
  end
end
