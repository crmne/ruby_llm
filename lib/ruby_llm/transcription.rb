# frozen_string_literal: true

module RubyLLM
  # Represents a transcription of audio content.
  class Transcription
    attr_reader :text, :model, :language, :duration, :segments, :input_tokens, :output_tokens

    def initialize(text:, model:, **attributes)
      @text = text
      @model = model
      @language = attributes[:language]
      @duration = attributes[:duration]
      @segments = attributes[:segments]
      @input_tokens = attributes[:input_tokens]
      @output_tokens = attributes[:output_tokens]
    end

    def self.transcribe(audio_file, **kwargs)
      model = kwargs.delete(:model)
      language = kwargs.delete(:language)
      provider = kwargs.delete(:provider)
      assume_model_exists = kwargs.delete(:assume_model_exists) { false }
      context = kwargs.delete(:context)
      options = kwargs

      config = context&.config || RubyLLM.config
      model ||= config.default_transcription_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      provider_instance.transcribe(audio_file, model: model_id, language:, **options)
    end
  end
end
