# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      # xAI's dialect of the Chat Completions API.
      class ChatCompletions < Protocols::ChatCompletions
        include XAI::Chat
        include XAI::ReportedCost
        include XAI::Images
        include XAI::Models
        include XAI::Speech
        include XAI::Transcription
        include Protocols::XAI::Tokenization
        include Protocols::XAI::StreamingTranscription
      end
    end
  end
end
