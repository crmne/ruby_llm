# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Handles formatting of media content (images, audio) for Ollama APIs
      module Media
        include OpenAI::Media

        module_function :format_content, :format_image, :format_audio, :format_pdf, :format_data_url
      end
    end
  end
end
