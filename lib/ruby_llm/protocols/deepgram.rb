# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Deepgram API: speech to text on v1/listen, text to speech on
    # v1/speak, and the model catalog behind them. Deepgram has no chat,
    # embedding, or image endpoints, so those seams are left unimplemented.
    #
    # Deepgram carries its request options in the query string rather than
    # the body, so +provider_options:+ joins the query on both audio
    # operations.
    class Deepgram < Protocol
      include Deepgram::Models
      include Deepgram::Speech
      include Deepgram::Transcription
    end
  end
end
