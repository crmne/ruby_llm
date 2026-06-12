# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Anthropic Messages API.
    class Anthropic < Protocol
      include Anthropic::Batches
      include Anthropic::Chat
      include Anthropic::Embeddings
      include Anthropic::Media
      include Anthropic::Models
      include Anthropic::Streaming
      include Anthropic::Tools
    end
  end
end
