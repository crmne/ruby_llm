# frozen_string_literal: true

module RubyLLM
  # A Speech is audio generated from text. RubyLLM.speak returns one. It
  # holds the raw audio bytes along with the model, voice, and format used.
  #
  #   speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
  #   speech.save "welcome.mp3"
  #
  class Speech
    include Support::Inspectable
    include Files::Saving
    include Accounting::Usage::Result
    include Accounting::Usage::ModelInfo

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

    def initialize(data:, model:, voice: nil, format: 'mp3', mime_type: nil, # :nodoc:
                   input_tokens: nil, output_tokens: nil, characters: nil)
      @data = data
      @model = model
      @voice = voice
      @format = (format || 'mp3').to_s
      @mime_type = mime_type || MIME_TYPES.fetch(@format, "audio/#{@format}")
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      @characters = characters
    end

    # Generates speech for +input+ and returns a Speech holding the audio.
    # Uses <tt>config.default_speech_model</tt> unless +model:+ is given.
    # Pass +provider:+ and <tt>assume_model_exists: true</tt> to use a model
    # that is not in the registry. +provider_options:+ takes options in the
    # provider's request vocabulary, such as +instructions:+ and +speed:+
    # for OpenAI, and merges them into the request as-is.
    # +owner:+ attributes the usage to a record, such as a user, and wins
    # over RubyLLM.with_usage_owner.
    #
    #   speech = RubyLLM.speak "Hello, welcome to RubyLLM!"
    #   speech.save "welcome.mp3"
    #
    #   RubyLLM.speak "Welcome back.", voice: "nova"
    #   RubyLLM.speak "Save this as a WAV file.", format: "wav"
    #   RubyLLM.speak "Say cheerfully: Have a wonderful day!",
    #                 model: "gemini-3.1-flash-tts-preview", provider: :gemini
    #
    # Given a block, yields SpeechChunk objects as audio arrives and still
    # returns the complete Speech. Chunks contain consecutive bytes of the
    # recording and are not separate audio files.
    #
    #   File.open("welcome.mp3", "wb") do |file|
    #     RubyLLM.speak("Welcome back.") { |chunk| file.write(chunk.data) }
    #   end
    #
    # Raises RubyLLM::Error when the selected protocol cannot stream speech,
    # or RubyLLM::ModelNotFoundError if +model:+ is not in the registry.
    def self.speak(input,
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   voice: nil,
                   format: nil,
                   context: nil,
                   provider_options: {},
                   metadata: nil,
                   owner: nil,
                   &block)
      Accounting::Operation.new(
        'speech', model, default: :default_speech_model, category: :audio_tokens, provider:, assume_model_exists:,
                         context:, owner:,
                         details: lambda { |event, result|
                           event[:voice] = result.voice
                           event[:format] = result.format
                           event[:audio_bytes] = result.to_blob.bytesize
                         }
      ).run(input:, voice:, format:, provider_options:, metadata:, streaming: !block.nil?) do |provider_instance, model|
        provider_instance.speak(input, model:, voice:, format:, provider_options:, &block)
      end
    end

    ##
    # :method: save
    # :call-seq:
    #   save(path)
    #
    # Writes the audio to +path+ in binary mode and returns +path+.
    #
    #   speech.save "welcome.mp3"

    # Returns the raw audio bytes. Alias for #data, mirroring Image#to_blob.
    def to_blob
      data
    end

    # Returns provider-reported usage across every attempt. Its fields are
    # +nil+ when the provider did not report any.
    def tokens
      return ruby_llm_usage_tokens unless ruby_llm_usage_entries.empty?

      Tokens.new(input: @input_tokens, output: @output_tokens, characters: @characters)
    end

    # Returns the speech cost across every provider attempt.
    def cost
      return ruby_llm_usage_cost unless ruby_llm_usage_entries.empty?

      Cost.new(tokens:, model: model_info, category: :audio_tokens)
    end

    def inspect_attributes # :nodoc:
      { model: model, voice: voice, format: format, data: data && "#{data.bytesize} bytes" }
    end
  end
end
