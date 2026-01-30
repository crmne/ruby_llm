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
                   assume_model_exists: false,
                   context: nil,
                   dimensions: nil,
                   with: nil)
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
        with: with
      )

      provider_instance.embed(**args)
    end

    def self.set_embedding_params(provider_instance,
                                  text: nil,
                                  model_id: nil,
                                  dimensions: nil,
                                  with: nil)
      embed_params = provider_instance.method(:embed).parameters.map(&:last)
      args = { model: model_id }
      args[:text] = text if text
      args[:dimensions] = dimensions if dimensions
      args[:with] = with if with && embed_params.include?(:with)
      args
    end
  end
end
