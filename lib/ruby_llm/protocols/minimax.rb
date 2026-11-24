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

      def stream_error?(data)
        super || (data.is_a?(Hash) && !@provider.failure_status(data).nil?)
      end

      def parse_streaming_error(data)
        status = @provider.failure_status(JSON.parse(data))
        status ? [status, nil] : super
      end

      def media_url(path)
        "#{@provider.media_base}/#{path}"
      end
    end
  end
end
