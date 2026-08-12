# frozen_string_literal: true

module RubyLLM
  module Providers
    class ElevenLabs
      # The ElevenLabs audio API: text to speech and the model catalog
      # behind it. ElevenLabs has no chat, embedding, or image endpoints,
      # so those seams are left unimplemented.
      class Audio < Protocol
        include ElevenLabs::Models
        include ElevenLabs::Speech
      end
    end
  end
end
