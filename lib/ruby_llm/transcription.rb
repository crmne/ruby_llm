# frozen_string_literal: true

module RubyLLM
  # Represents a transcription of audio content.
  class Transcription
    attr_reader :text, :model, :language, :duration, :segments, :words, :input_tokens, :output_tokens

    def initialize(text:, model:, **attributes)
      @text = text
      @model = model
      @language = attributes[:language]
      @duration = attributes[:duration]
      @segments = attributes[:segments]
      @words = attributes[:words]
      @input_tokens = attributes[:input_tokens]
      @output_tokens = attributes[:output_tokens]
    end

    def self.transcribe(audio_file, # rubocop:disable Metrics/ParameterLists
                        model: nil,
                        language: nil,
                        provider: nil,
                        assume_model_exists: false,
                        context: nil,
                        **options)
      config = context&.config || RubyLLM.config
      model ||= config.default_transcription_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        language: language
      }

      RubyLLM.instrument('transcription.ruby_llm', payload, config: config) do |event|
        result = provider_instance.transcribe(audio_file, model: model.id, language:, **options)
        event[:result] = result
        event[:response_model] = result.model
        event[:input_tokens] = result.input_tokens
        event[:output_tokens] = result.output_tokens
        result
      end
    end
  end
end
