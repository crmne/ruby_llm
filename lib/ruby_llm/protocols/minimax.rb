# frozen_string_literal: true

module RubyLLM
  module Protocols
    # MiniMax's own media API at the root of its host, beside the
    # Anthropic-compatible chat endpoint: images, videos, speech, and
    # transcription.
    class MiniMax < Protocol
      include MiniMax::Images
      include MiniMax::Videos
      include MiniMax::Speech
      include MiniMax::Transcription

      private

      def media_url(path)
        "#{@provider.media_base}/#{path}"
      end
    end
  end
end
