# frozen_string_literal: true

module RubyLLM
  # Represents audio generated from text.
  class Speech
    MIME_TYPES = {
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'mp3' => 'audio/mpeg',
      'opus' => 'audio/opus',
      'pcm' => 'audio/pcm',
      'wav' => 'audio/wav'
    }.freeze

    attr_reader :data, :model, :voice, :format, :mime_type

    def initialize(data:, model:, voice: nil, format: 'mp3', mime_type: nil)
      @data = data
      @model = model
      @voice = voice
      @format = (format || 'mp3').to_s
      @mime_type = mime_type || MIME_TYPES.fetch(@format, "audio/#{@format}")
    end

    def self.speak(input, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   voice: nil,
                   format: nil,
                   context: nil,
                   instructions: nil,
                   speed: nil,
                   params: {},
                   metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_speech_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)

      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        input: input,
        voice: voice,
        format: format,
        params: params,
        metadata: metadata
      }

      RubyLLM.instrument('speech.ruby_llm', payload, config: config) do |event|
        options = { instructions:, speed: }.compact
        result = provider_instance.speak(input, model:, voice:, format:, params:, **options)
        event[:result] = result
        event[:response_model] = result.model
        event[:voice] = result.voice
        event[:format] = result.format
        event[:audio_bytes] = result.to_blob.bytesize
        result
      end
    end

    def to_blob
      data
    end

    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end
  end
end
