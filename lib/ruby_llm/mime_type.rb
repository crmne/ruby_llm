# frozen_string_literal: true

require 'marcel'

module RubyLLM
  # MimeType module provides methods to handle MIME types using Marcel gem
  module MimeType
    module_function

    def for(...)
      Marcel::MimeType.for(...)
    end

    def image?(type)
      type.start_with?('image/')
    end

    def audio?(type)
      type.start_with?('audio/')
    end

    def pdf?(type)
      type == 'application/pdf'
    end
  end
end
