# frozen_string_literal: true

module RubyLLM
  # Core embedding interface. Provides a clean way to generate embeddings
  # from text using various provider models.
  class Embedding
    attr_reader :vectors, :model, :input_tokens

    def initialize(vectors:, model:, input_tokens: 0)
      @vectors = vectors
      @model = model
      @input_tokens = input_tokens
    end

    def self.embed(text, model: nil, dimensions: nil)
      model_id = model || RubyLLM.config.default_embedding_model
      Models.find(model_id)

      provider = Provider.for(model_id)
      provider.embed(text, model: model_id, dimensions:)
    end
  end
end
