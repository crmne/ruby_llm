# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Handles formatting of media content (images, audio) for Bedrock APIs
      module Media
        include Anthropic::Media

        module_function :format_content, :format_image, :format_pdf, :format_text_block
      end
    end
  end
end
