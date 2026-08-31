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
      end
    end
  end
end
