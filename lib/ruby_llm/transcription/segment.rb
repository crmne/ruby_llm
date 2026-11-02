# frozen_string_literal: true

module RubyLLM
  class Transcription
    # A timed piece of a transcript: an entry of Transcription#segments or
    # Transcription#words, or the TranscriptionChunk#segment a stream
    # completed. Readers cover what providers share; #[] and #to_h reach
    # the rest under the provider's own field names.
    #
    #   transcription.segments.each do |segment|
    #     puts "#{segment.speaker} at #{segment.start}s: #{segment.text}"
    #   end
    #
    class Segment
      include Support::Inspectable

      def self.wrap(segments) # :nodoc:
        segments&.map { |segment| new(segment) }
      end

      def initialize(attributes) # :nodoc:
        @attributes = attributes.to_h.transform_keys(&:to_s)
      end

      # The spoken text, or +nil+ when the provider reports none.
      def text = self['text'] || self['word'] || self['transcript']

      # The speaker label, or +nil+ on models that do not separate speakers.
      def speaker = self['speaker'] || self['speaker_id']

      # When the text starts, in seconds from the start of the audio.
      def start = self['start']

      # When the text ends, in seconds from the start of the audio.
      def end = self['end']

      # Returns the provider's field named +key+, a String or Symbol.
      def [](key)
        @attributes[key.to_s]
      end

      # Returns the provider's field named +key+ the way Hash#fetch does.
      def fetch(key, ...)
        @attributes.fetch(key.to_s, ...)
      end

      # Returns +true+ when the provider sent a field named +key+.
      def key?(key) = @attributes.key?(key.to_s)
      alias has_key? key?

      # Returns the provider's fields as a Hash with String keys.
      def to_h = @attributes.dup
      alias to_hash to_h

      # Returns +true+ for a Segment or Hash holding the same fields.
      def ==(other)
        other.respond_to?(:to_h) && to_h == other.to_h.transform_keys(&:to_s)
      end

      private

      def inspect_attributes
        { text:, speaker:, start:, end: self.end }
      end
    end
  end
end
