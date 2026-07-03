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
                        prompt: nil,
                        temperature: nil,
                        response_format: nil,
                        timestamp_granularities: nil,
                        speaker_names: nil,
                        speaker_references: nil,
                        chunking_strategy: nil,
                        response_mime_type: nil,
                        max_output_tokens: nil,
                        safety_settings: nil,
                        params: {},
                        metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_transcription_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model.id,
        model_info: model,
        language: language,
        params: params,
        metadata: metadata
      }

      RubyLLM.instrument('transcription.ruby_llm', payload, config: config) do |event|
        options = {
          prompt: prompt,
          temperature: temperature,
          response_format: response_format,
          timestamp_granularities: timestamp_granularities,
          speaker_names: speaker_names,
          speaker_references: speaker_references,
          chunking_strategy: chunking_strategy,
          response_mime_type: response_mime_type,
          max_output_tokens: max_output_tokens,
          safety_settings: safety_settings
        }.compact

        result = provider_instance.transcribe(audio_file, model:, language:, params:, **options)
        event[:result] = result
        event[:response_model] = result.model
        event[:input_tokens] = result.input_tokens
        event[:output_tokens] = result.output_tokens
        result
      end
    end
  end
end
