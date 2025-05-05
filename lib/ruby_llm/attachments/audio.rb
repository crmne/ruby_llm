# frozen_string_literal: true

module RubyLLM
  module Attachments
    # Represents an audio attachment
    class Audio < Base
      def format
        File.extname(@source).downcase.delete('.') || 'wav'
      end
    end
  end
end
