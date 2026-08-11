# frozen_string_literal: true

module RubyLLM
  # An EmbeddingRequest is an embedding awaiting a provider-side batch.
  # RubyLLM.embed_later stages one; submit an array of them with
  # RubyLLM.batch, and once the batch completes, collecting the results
  # fills in #result:
  #
  #   requests = texts.map { |text| RubyLLM.embed_later(text) }
  #   batch = RubyLLM.batch(requests)
  #   # later, once batch.refresh.complete?
  #   batch.results
  #   requests.first.result.vectors
  #
  class EmbeddingRequest
    include Inspectable

    # The text staged for embedding.
    attr_reader :text

    # The Model::Info of the embedding model the request targets.
    attr_reader :model

    # The requested vector size, or +nil+ for the model's default.
    attr_reader :dimensions

    # The Provider the request will be submitted through.
    attr_reader :provider

    # The Embedding, once the batch has completed and its results have
    # been collected. +nil+ until then, and for requests that failed.
    # Batch result collection writes it.
    attr_accessor :result

    def initialize(text, model: nil, provider: nil, dimensions: nil, context: nil) # :nodoc:
      config = context&.config || RubyLLM.config
      model ||= config.default_embedding_model
      @model, @provider = Models.resolve(model, provider:, config:)
      @text = text
      @dimensions = dimensions
    end

    # Returns the request payload this embedding request would send to the
    # provider, in the provider's wire format.
    def render
      @provider.render_embedding(text, model: @model, dimensions: @dimensions)
    end

    def inspect_attributes # :nodoc:
      { text: text, model: model.id, dimensions: dimensions, result: result }
    end
  end
end
