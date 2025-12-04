# frozen_string_literal: true

module RubyLLM
  # Core embedding interface.
  class Embedding
    extend Instrumentation

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

      instrument('embed_text.ruby_llm',
                 { provider: provider_instance.slug, model: model_id, dimensions: dimensions }) do |payload|
        provider_instance.embed(text, model: model_id, dimensions:).tap do |result|
          if payload
            payload[:input_tokens] = result.input_tokens unless result.input_tokens.nil?
            payload[:vector_count] = result.vectors.is_a?(Array) ? result.vectors.length : 1
          end
        end
      end
    end
  end
end
