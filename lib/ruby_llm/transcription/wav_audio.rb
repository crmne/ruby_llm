# frozen_string_literal: true

module RubyLLM
  class Transcription
    class WavAudio # :nodoc: all
      attr_reader :data, :sample_rate, :channels, :bits_per_sample, :encoding

      def initialize(content)
        content = wav_content(content)
        parse_chunks(content)
        raise ArgumentError, 'WAV file must contain audio data and format information' unless @data && @sample_rate
      end

      def duration
        data.bytesize.fdiv(sample_rate * channels * bits_per_sample / 8)
      end

      private

      def wav_content(content)
        unless content.start_with?('RIFF') && content.byteslice(8, 4) == 'WAVE'
          raise ArgumentError, 'This streaming transcription endpoint requires a WAV file'
        end

        declared_size = content.byteslice(4, 4).unpack1('V')
        return content if declared_size == 0xFFFFFFFF
        raise ArgumentError, 'WAV file is truncated' if content.bytesize < declared_size + 8

        content.byteslice(0, declared_size + 8)
      end

      def parse_chunks(content)
        offset = 12
        while offset + 8 <= content.bytesize
          name = content.byteslice(offset, 4)
          length = content.byteslice(offset + 4, 4).unpack1('V')
          length = content.bytesize - offset - 8 if name == 'data' && length == 0xFFFFFFFF
          body = content.byteslice(offset + 8, length)
          validate_chunk_length(body, length)

          parse_format(body) if name == 'fmt '
          @data = body.b if name == 'data'
          offset += 8 + length + (length % 2)
        end
        raise ArgumentError, 'WAV file contains a truncated chunk or padding' unless offset == content.bytesize
      end

      def validate_chunk_length(body, length)
        raise ArgumentError, 'WAV file contains a truncated chunk' unless body && body.bytesize == length
      end

      def parse_format(data)
        raise ArgumentError, 'WAV file contains an invalid audio format' if data.bytesize < 16

        @encoding, @channels, @sample_rate, _, _, @bits_per_sample = data.unpack('vvVVvv')
        return if @channels.positive? && @sample_rate.positive? && @bits_per_sample.positive?

        raise ArgumentError, 'WAV file contains an invalid audio format'
      end
    end
  end
end
