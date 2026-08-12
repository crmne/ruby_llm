# frozen_string_literal: true

module RubyLLM
  # A TranscriptionChunk is one event from a streaming transcription.
  # RubyLLM.transcribe yields these to its block as the provider transcribes
  # the audio, then returns the final Transcription.
  #
  #   RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe") do |chunk|
  #     print chunk.delta if chunk.delta?
  #   end
  #
  class TranscriptionChunk
    include Inspectable

    # Text deltas, arriving as the model transcribes.
    DELTA = 'transcript.text.delta'

    # A completed segment, on models that return timed or diarized segments.
    SEGMENT = 'transcript.text.segment'

    # The final event, carrying the complete transcript.
    DONE = 'transcript.text.done'

    # The event type in the provider's vocabulary, such as
    # <tt>"transcript.text.delta"</tt>.
    attr_reader :type

    # The text added by this event, or +nil+ for events that add no text.
    attr_reader :delta

    # The complete transcript so far. Only the final event reports it.
    attr_reader :text

    # The segment this event completed as a Hash, or +nil+. Diarization
    # models label each segment with a speaker.
    attr_reader :segment

    # The parsed provider event, for fields RubyLLM does not normalize.
    attr_reader :raw

    def initialize(type:, delta: nil, text: nil, segment: nil, raw: nil) # :nodoc:
      @type = type
      @delta = delta
      @text = text
      @segment = segment
      @raw = raw
    end

    # Whether this event carries a text delta.
    def delta? = !delta.nil?

    # Whether this event completed a segment.
    def segment? = !segment.nil?

    # Whether this is the final event of the transcription.
    def done? = type == DONE

    def inspect_attributes # :nodoc:
      { type: type, delta: delta, text: text, segment: segment }
    end
  end
end
