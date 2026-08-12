# frozen_string_literal: true

module RubyLLM
  module Providers
    class ElevenLabs
      # The ElevenLabs audio API: text to speech, speech to text, and the
      # model catalog behind them. ElevenLabs has no chat, embedding, or
      # image endpoints, so those seams are left unimplemented.
      class Audio < Protocol
        include ElevenLabs::Models
        include ElevenLabs::Speech
        include ElevenLabs::Transcription
      end
    end
  end
end
