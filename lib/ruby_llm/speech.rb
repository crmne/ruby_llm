# frozen_string_literal: true

module RubyLLM
  # Represents a generated image from an AI model.
  class Speech
    attr_reader :model, :data

    def initialize(data:, model: nil)
      @model = model
      @data = data
    end

    def save(path)
      File.binwrite(File.expand_path(path), data)
      path
    end

    def self.tts(input, # rubocop:disable Metrics/ParameterLists
                 model: nil,
                 provider: nil,
                 assume_model_exists: false,
                 voice: 'alloy',
                 context: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_audio_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)

      provider_instance.tts(input, model: model.id, voice:)
    end
  end
end
