# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Azure
      # The Azure AI Speech API on an Azure AI Services resource. Only fast
      # transcription is implemented; chat, embeddings, and images go through
      # the resource's OpenAI-compatible protocols.
      class Speech < Protocol
        include Speech::Transcription
      end
    end
  end
end
