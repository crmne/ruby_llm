# frozen_string_literal: true

module RubyLLM
  # Core embedding interface.
  class Embedding
    attr_reader :vectors, :model, :input_tokens

    def initialize(vectors:, model:, input_tokens: 0)
      @vectors = vectors
      @model = model
      @input_tokens = input_tokens
    end

    def self.embed(text = nil, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   image: nil,
                   video: nil,
                   assume_model_exists: false,
                   context: nil,
                   dimensions: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_embedding_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id
      args = set_embedding_params(
        provider_instance,
        text: text,
        model_id: model_id,
        dimensions: dimensions,
        image: image,
        video: video
      )

      provider_instance.embed(**args)
    end

    def self.set_embedding_params(provider_instance, # rubocop:disable Metrics/ParameterLists
                                  text: nil,
                                  model_id: nil,
                                  dimensions: nil,
                                  image: nil,
                                  video: nil)
      embed_params = provider_instance.method(:embed).parameters.map(&:last)
      args = { model: model_id }
      args[:text] = text if text
      args[:dimensions] = dimensions if dimensions
      args[:image] = image if image && embed_params.include?(:image)
      args[:video] = video if video && embed_params.include?(:video)
      args
    end
  end
end
