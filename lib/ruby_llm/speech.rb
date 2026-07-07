# frozen_string_literal: true

module RubyLLM
  # A Speech is audio generated from text. RubyLLM.speak returns one. It
  # holds the raw audio bytes along with the model, voice, and format used.
  #
  #   speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
  #   speech.save "welcome.mp3"
  #
  class Speech
    # Maps audio format names to their MIME types.
    MIME_TYPES = {
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'mp3' => 'audio/mpeg',
      'opus' => 'audio/opus',
      'pcm' => 'audio/pcm',
      'wav' => 'audio/wav'
    }.freeze

    # The raw audio bytes returned by the provider.
    attr_reader :data

    # The id of the model that generated the audio.
    attr_reader :model

    # The voice used for synthesis. When no +voice:+ was given, this is the
    # provider default.
    attr_reader :voice

    # The audio format name, such as <tt>"mp3"</tt> or <tt>"pcm"</tt>.
    attr_reader :format

    # The MIME type of the audio, such as <tt>"audio/mpeg"</tt>.
    attr_reader :mime_type

    def initialize(data:, model:, voice: nil, format: 'mp3', mime_type: nil) # :nodoc:
      @data = data
      @model = model
      @voice = voice
      @format = (format || 'mp3').to_s
      @mime_type = mime_type || MIME_TYPES.fetch(@format, "audio/#{@format}")
    end

    # Generates speech for +input+ and returns a Speech holding the audio.
    # Uses <tt>config.default_speech_model</tt> unless +model:+ is given.
    # Pass +provider:+ and <tt>assume_model_exists: true</tt> to use a model
    # that is not in the registry. +provider_options:+ takes options in the
    # provider's request vocabulary, such as +instructions:+ and +speed:+
    # for OpenAI, and merges them into the request as-is.
    #
    #   speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
    #   speech.save "welcome.mp3"
    #
    #   RubyLLM.speak "Welcome back.", voice: "nova"
    #   RubyLLM.speak "Save this as a WAV file.", format: "wav"
    #   RubyLLM.speak "Say cheerfully: Have a wonderful day!",
    #                 model: "gemini-2.5-flash-preview-tts", provider: :gemini
    #
    # Raises RubyLLM::ModelNotFoundError if +model:+ is not in the registry.
    def self.speak(input, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   voice: nil,
                   format: nil,
                   context: nil,
                   provider_options: {},
                   metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_speech_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)

      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        input: input,
        voice: voice,
        format: format,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('speech.ruby_llm', payload, config: config) do |event|
        result = provider_instance.speak(input, model:, voice:, format:, provider_options:)
        event[:result] = result
        event[:response_model] = result.model
        event[:voice] = result.voice
        event[:format] = result.format
        event[:audio_bytes] = result.to_blob.bytesize
        result
      end
    end

    # Returns the raw audio bytes. Alias for #data, mirroring Image#to_blob.
    def to_blob
      data
    end

    # Writes the audio to +path+ in binary mode and returns +path+.
    #
    #   speech.save "welcome.mp3"
    #
    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end
  end
end
