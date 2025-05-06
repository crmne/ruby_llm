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

    def self.embed(text, # rubocop:disable Metrics/ParameterLists,Metrics/CyclomaticComplexity
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   context: nil,
                   dimensions: nil)
      config = context&.config || RubyLLM.config
      model, provider = Models.resolve(model, provider: provider, assume_exists: assume_model_exists) if model
      model_id = model&.id || config.default_embedding_model

      provider = Provider.for(model_id) if provider.nil?
      connection = context ? context.connection_for(provider) : provider.connection(config)
      provider.embed(text, model: model_id, connection:, dimensions:)
    end
  end
end
