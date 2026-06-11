# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The OpenAI Chat Completions API — the lingua franca of LLM APIs.
    class ChatCompletions < Protocol
      include ChatCompletions::Chat
      include ChatCompletions::Embeddings
      include ChatCompletions::Models
      include ChatCompletions::Moderation
      include ChatCompletions::Streaming
      include ChatCompletions::Tools
      include ChatCompletions::Images
      include ChatCompletions::Media
      include ChatCompletions::Transcription

      def maybe_normalize_temperature(temperature, model)
        Temperature.normalize(temperature, model.id)
      end
    end
  end
end
