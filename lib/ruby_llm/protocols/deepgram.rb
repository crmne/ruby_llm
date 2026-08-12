# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The Deepgram API: the model catalog, and the audio endpoints behind
    # it. Deepgram has no chat, embedding, or image endpoints, so those
    # seams are left unimplemented.
    class Deepgram < Protocol
      include Deepgram::Models
    end
  end
end
