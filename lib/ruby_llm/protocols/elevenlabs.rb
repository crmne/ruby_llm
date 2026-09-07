# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The ElevenLabs audio API: text to speech, speech to text, and the model
    # catalog behind them. Image and video generation and workspace assets use
    # separate protocols.
    class ElevenLabs < Protocol
      include ElevenLabs::Models
      include ElevenLabs::Speech
      include ElevenLabs::Transcription
      include ElevenLabs::StreamingTranscription
    end
  end
end
