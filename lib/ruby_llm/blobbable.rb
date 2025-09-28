# frozen_string_literal: true

module RubyLLM
  # Mixin for classes that can be used to save a blob to a file
  module Blobbable
    def save(path)
      if (blob = to_blob)
        File.binwrite(File.expand_path(path), blob)
        path
      end
    end

    def to_blob
      raise NotImplementedError, 'to_blob is not implemented'
    end
  end
end
