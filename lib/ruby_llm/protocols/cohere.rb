# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Cohere v2 API, a native wire format shared by Cohere's own host and
    # the platforms that serve Command, Embed, Rerank, and Transcribe models.
    class Cohere < Protocol
      include Cohere::Chat
      include Cohere::Embeddings
      include Cohere::Media
      include Cohere::Models
      include Cohere::Rerank
      include Cohere::Streaming
      include Cohere::Tools
      include Cohere::Transcription
    end
  end
end
