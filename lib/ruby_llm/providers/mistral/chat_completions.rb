# frozen_string_literal: true

module RubyLLM
  module Providers
    class Mistral
      # Mistral's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include Mistral::Chat
        include Mistral::Embeddings
        include Mistral::Media
        include Mistral::Models
        include Mistral::OCR
        include Mistral::Speech
        include Mistral::Transcription
        include Protocols::Mistral::MultiCompletion

        public :server_tool_aliases
      end
    end
  end
end
