# frozen_string_literal: true

module RubyLLM
  # A Transcription is text produced from spoken audio. RubyLLM.transcribe
  # returns one. It holds the transcript along with any metadata the provider
  # reports, such as language, duration, and timed segments.
  #
  #   transcription = RubyLLM.transcribe("meeting.wav")
  #   transcription.text   # => "Welcome to today's meeting..."
  #   transcription.model  # => "gpt-transcribe"
  #
  class Transcription
    include Support::Inspectable
    include Accounting::Usage::Result
    include Accounting::Usage::ModelInfo

    # The transcribed text.
    attr_reader :text

    # The id of the model that produced the transcription.
    attr_reader :model

    # The language of the audio, or +nil+ when the provider does not report it.
    attr_reader :language

    # The audio duration in seconds, or +nil+ when the provider does not
    # report it.
    attr_reader :duration

    # The timed segments of the transcript as an array of Segment objects,
    # or +nil+ when the provider does not return segments. Diarization
    # models add a speaker label to each segment.
    attr_reader :segments

    # Word timing and speaker labels as an array of Segment objects, or
    # +nil+ when the provider does not return them. Request timing with
    # +timestamps:+.
    attr_reader :words

    def initialize(text:, model:, **attributes) # :nodoc:
      @text = text
      @model = model
      @language = attributes[:language]
      @duration = attributes[:duration]
      @segments = Segment.wrap(attributes[:segments])
      @words = Segment.wrap(attributes[:words])
      @input_tokens = attributes[:input_tokens]
      @output_tokens = attributes[:output_tokens]
      @reported_cost = attributes[:reported_cost]
    end

    # Returns usage aggregated across every provider attempt.
    def tokens
      return ruby_llm_usage_tokens unless ruby_llm_usage_entries.empty?

      Tokens.new(input: @input_tokens, output: @output_tokens, reported_cost: @reported_cost)
    end

    # Returns the transcription cost across every provider attempt.
    def cost
      return ruby_llm_usage_cost unless ruby_llm_usage_entries.empty?

      Cost.new(tokens:, model: model_info, category: :audio_tokens)
    end

    # Transcribes +audio_file+ and returns a Transcription. The file may be
    # a path, URL, IO object, or Attachment. Uses
    # <tt>config.default_transcription_model</tt> unless +model:+ is given.
    # Pass +provider:+ and <tt>assume_model_exists: true</tt> to use a model
    # that is not in the registry.
    #
    #   RubyLLM.transcribe("meeting.wav")
    #   RubyLLM.transcribe("entrevista.mp3", language: "es")
    #   RubyLLM.transcribe(
    #     "team-meeting.wav",
    #     model: "gpt-4o-transcribe-diarize",
    #     speaker_names: ["Alice", "Bob"],
    #     speaker_references: ["alice-voice.wav", "bob-voice.wav"]
    #   )
    #
    # +language:+ hints at the spoken language using the provider's accepted
    # ISO 639-1 or BCP-47 language code.
    # +prompt:+ gives the model vocabulary or formatting guidance, and
    # +temperature:+ adjusts sampling. +format:+ selects the transcript
    # format in the provider's own vocabulary: OpenAI takes values such as
    # <tt>"text"</tt>, <tt>"verbose_json"</tt>, or <tt>"diarized_json"</tt>,
    # while Gemini takes a MIME type such as <tt>"text/plain"</tt>.
    # +speaker_names:+ and +speaker_references:+ label the speakers on
    # models that support diarization; references may be paths, URLs, IO
    # objects, or Attachments. Option support depends on the selected model
    # and provider.
    # +timestamps:+ requests +:word+ timestamps. Some providers also accept
    # +:segment+ or +:character+; unsupported granularities raise ArgumentError.
    # +provider_options:+ takes options in the provider's request vocabulary
    # and merges them into the rendered request as-is.
    # +owner:+ attributes the usage to a record, such as a user, and wins
    # over RubyLLM.with_usage_owner.
    #
    # Given a block, the transcript streams: each TranscriptionChunk is
    # yielded as it arrives and the completed Transcription is still
    # returned. Partial chunks replace earlier tentative text; only
    # +delta+ fields append to the committed transcript. WebSocket-based
    # providers require the optional +websocket-driver+ gem.
    #
    #   transcription = RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe") do |chunk|
    #     print chunk.delta
    #   end
    #
    # Raises RubyLLM::ModelNotFoundError if +model:+ is not in the registry,
    # and RubyLLM::Error when a block is given to a provider that does not
    # stream transcriptions.
    def self.transcribe(audio_file,
                        model: nil,
                        language: nil,
                        provider: nil,
                        assume_model_exists: false,
                        context: nil,
                        prompt: nil,
                        temperature: nil,
                        format: nil,
                        timestamps: nil,
                        speaker_names: nil,
                        speaker_references: nil,
                        provider_options: {},
                        metadata: nil,
                        owner: nil,
                        &block)
      Accounting::Operation.new(
        'transcription', model, default: :default_transcription_model, category: :audio_tokens, provider:,
                                assume_model_exists:, context:, owner:
      ).run(streaming: !block.nil?, language:, temperature:, provider_options:, metadata:) do |provider_instance, model|
        provider_instance.transcribe(audio_file, model:, language:, format:, timestamps:, speaker_names:,
                                                 speaker_references:, provider_options:, prompt:, temperature:, &block)
      end
    end

    def inspect_attributes # :nodoc:
      { text: text, model: model, language: language, duration: duration }
    end
  end
end
