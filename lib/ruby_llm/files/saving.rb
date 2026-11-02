# frozen_string_literal: true

module RubyLLM
  module Files
    # The #save every complete downloadable result shares. Includers supply
    # #to_blob and document #save in their own terms.
    module Saving # :nodoc:
      def save(path)
        File.binwrite(File.expand_path(path), to_blob)
        path
      end
    end
  end
end
