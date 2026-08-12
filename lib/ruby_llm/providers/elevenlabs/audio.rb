# frozen_string_literal: true

module RubyLLM
  module Providers
    class ElevenLabs
      # The ElevenLabs audio API and the model catalog behind it.
      # ElevenLabs has no chat, embedding, or image endpoints, so those
      # seams are left unimplemented.
      class Audio < Protocol
        include ElevenLabs::Models
      end
    end
  end
end
