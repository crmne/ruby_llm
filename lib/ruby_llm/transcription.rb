# frozen_string_literal: true

module RubyLLM
  # A Transcription is text produced from spoken audio. RubyLLM.transcribe
  # returns one. It holds the transcript along with any metadata the provider
  # reports, such as language, duration, and timed segments.
  #
  #   transcription = RubyLLM.transcribe("meeting.wav")
  #   transcription.text   # => "Welcome to today's meeting..."
  #   transcription.model  # => "whisper-1"
  #
  class Transcription
    # The transcribed text.
    attr_reader :text

    # The id of the model that produced the transcription.
    attr_reader :model

    # The language of the audio, or +nil+ when the provider does not report it.
    attr_reader :language

    # The audio duration in seconds, or +nil+ when the provider does not
    # report it.
    attr_reader :duration

    # The timed segments of the transcript as an array of hashes, or +nil+
    # when the provider does not return segments. Diarization models add a
    # speaker label to each segment.
    attr_reader :segments

    # Word-level timestamps as an array of hashes, or +nil+ unless requested
    # through +format:+ and +provider_options:+ on models that support them.
    attr_reader :words

    # The number of input tokens reported by the provider, or +nil+.
    attr_reader :input_tokens

    # The number of output tokens reported by the provider, or +nil+.
    attr_reader :output_tokens

    def initialize(text:, model:, **attributes) # :nodoc:
      @text = text
      @model = model
      @language = attributes[:language]
      @duration = attributes[:duration]
      @segments = attributes[:segments]
      @words = attributes[:words]
      @input_tokens = attributes[:input_tokens]
      @output_tokens = attributes[:output_tokens]
    end

    # Transcribes +audio_file+ and returns a Transcription. The file may be
    # a path, URL, or IO object. Uses
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
    # +language:+ hints at the spoken language as an ISO 639-1 code.
    # +prompt:+ gives the model vocabulary or formatting guidance, and
    # +temperature:+ adjusts sampling. +format:+ selects the transcript
    # format in the provider's own vocabulary: OpenAI takes values such as
    # <tt>"text"</tt>, <tt>"verbose_json"</tt>, or <tt>"diarized_json"</tt>,
    # while Gemini takes a MIME type such as <tt>"text/plain"</tt>.
    # +speaker_names:+ and +speaker_references:+ label the speakers on
    # models that support diarization; references may be paths, URLs, or IO
    # objects. Providers silently ignore the options they do not support.
    # +provider_options:+ takes options in the provider's request vocabulary
    # and merges them into the rendered request as-is.
    #
    # Raises RubyLLM::ModelNotFoundError if +model:+ is not in the registry.
    def self.transcribe(audio_file, # rubocop:disable Metrics/ParameterLists
                        model: nil,
                        language: nil,
                        provider: nil,
                        assume_model_exists: false,
                        context: nil,
                        prompt: nil,
                        temperature: nil,
                        format: nil,
                        speaker_names: nil,
                        speaker_references: nil,
                        provider_options: {},
                        metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_transcription_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        language: language,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('transcription.ruby_llm', payload, config: config) do |event|
        result = provider_instance.transcribe(audio_file, model:, language:, format:, speaker_names:,
                                                          speaker_references:, provider_options:, prompt:,
                                                          temperature:)
        event[:result] = result
        event[:response_model] = result.model
        event[:input_tokens] = result.input_tokens
        event[:output_tokens] = result.output_tokens
        result
      end
    end
  end
end
