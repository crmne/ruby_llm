# frozen_string_literal: true

module RubyLLM
  module Attachments
    # Represents an audio attachment
    class Image < Base
      def mime_type
        ext = File.extname(@source).downcase.delete('.')
        "image/#{ext}"
      end
    end
  end
end
