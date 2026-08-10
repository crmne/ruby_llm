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
        include Mistral::Speech
      end
    end
  end
end
