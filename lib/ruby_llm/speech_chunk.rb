# frozen_string_literal: true

module RubyLLM
  # A piece of generated audio, yielded by RubyLLM.speak as it arrives.
  # Chunks are consecutive bytes of one recording, not separate audio files.
  class SpeechChunk
    include Support::Inspectable

    # The raw audio bytes in this chunk.
    attr_reader :data

    # The audio format name, such as <tt>"mp3"</tt> or <tt>"pcm"</tt>.
    attr_reader :format

    # The MIME type of the audio, such as <tt>"audio/mpeg"</tt>.
    attr_reader :mime_type

    def initialize(data:, format:, mime_type: nil) # :nodoc:
      @data = data.b
      @format = format.to_s
      @mime_type = mime_type || Speech::MIME_TYPES.fetch(@format, "audio/#{@format}")
    end

    # Returns the raw audio bytes. Alias for #data.
    def to_blob
      data
    end

    def inspect_attributes # :nodoc:
      { format: format, data: "#{data.bytesize} bytes" }
    end
  end
end
