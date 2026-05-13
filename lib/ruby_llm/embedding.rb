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

    def self.embed(text, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   context: nil,
                   dimensions: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_embedding_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.name,
        model: model_id,
        model_info: model,
        input: text,
        dimensions: dimensions
      }

      RubyLLM.instrument('embedding.ruby_llm', payload, config: config) do |event|
        result = provider_instance.embed(text, model: model_id, dimensions:)
        event[:result] = result
        event[:response_model] = result.model
        event[:input_tokens] = result.input_tokens
        event[:embedding_dimensions] = vector_dimensions(result.vectors)
        event[:embedding_count] = embedding_count(result.vectors)
        result
      end
    end

    def self.vector_dimensions(vectors)
      return unless vectors.is_a?(Array)

      vector = vectors.first.is_a?(Array) ? vectors.first : vectors
      vector.length if vector.respond_to?(:length)
    end

    def self.embedding_count(vectors)
      return unless vectors.is_a?(Array)

      vectors.first.is_a?(Array) ? vectors.size : 1
    end
  end
end
