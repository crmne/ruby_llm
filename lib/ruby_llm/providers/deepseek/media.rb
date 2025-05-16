# frozen_string_literal: true

module RubyLLM
  module Providers
    module DeepSeek
      # Handles formatting of media content (images, audio) for DeepSeek APIs
      module Media
        include OpenAI::Media

        module_function :format_content, :format_image, :format_pdf, :format_audio, :format_text
      end
    end
  end
end
