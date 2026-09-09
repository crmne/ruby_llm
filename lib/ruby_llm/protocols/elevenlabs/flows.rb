# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      # The asynchronous ElevenLabs Image & Video API.
      class Flows < Protocol
        include Flows::Media
        include Flows::Images
        include Flows::Videos
      end
    end
  end
end
