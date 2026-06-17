# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Google Gemini generateContent API.
    class Gemini < Protocol
      include Gemini::Chat
      include Gemini::Embeddings
      include Gemini::Images
      include Gemini::Media
      include Gemini::Models
      include Gemini::Streaming
      include Gemini::Tools
      include Gemini::Transcription
    end
  end
end
