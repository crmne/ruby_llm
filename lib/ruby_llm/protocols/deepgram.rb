# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Deepgram API: speech to text on v1/listen, and the model catalog
    # behind it. Deepgram has no chat, embedding, or image endpoints, so
    # those seams are left unimplemented.
    #
    # Deepgram carries its request options in the query string rather than
    # the body, so +provider_options:+ joins the query.
    class Deepgram < Protocol
      include Deepgram::Models
      include Deepgram::Transcription
    end
  end
end
