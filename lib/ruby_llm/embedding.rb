# frozen_string_literal: true

module RubyLLM
  # An Embedding is the result of turning text into numerical vectors.
  # RubyLLM.embed returns one:
  #
  #   embedding = RubyLLM.embed("Ruby is a programmer's best friend")
  #   embedding.vectors.length  # => 1536
  #   embedding.model           # => "text-embedding-3-small"
  #   embedding.input_tokens    # => 8
  #
  class Embedding
    # The embedding vectors. A flat array of floats when a single text
    # was embedded, an array of such arrays when an array of texts was
    # embedded.
    attr_reader :vectors

    # The id of the model that produced the vectors, as a String.
    attr_reader :model

    # The number of input tokens consumed, or 0 when the provider
    # reports no usage.
    attr_reader :input_tokens

    def initialize(vectors:, model:, input_tokens: 0) # :nodoc:
      @vectors = vectors
      @model = model
      @input_tokens = input_tokens
    end

    # Generates embeddings for +text+ and returns an Embedding. +text+
    # may be a single string or an array of strings; an array produces
    # one vector per string in a single API call.
    #
    #   RubyLLM.embed "Ruby is a programmer's best friend"
    #   RubyLLM.embed ["Ruby", "Python", "JavaScript"]
    #   RubyLLM.embed "This is a test sentence",
    #                 model: "text-embedding-3-large",
    #                 dimensions: 512
    #   RubyLLM.embed "RubyLLM makes provider APIs feel native to Ruby.",
    #                 model: "text-embedding-004",
    #                 provider: :vertexai,
    #                 task_type: "RETRIEVAL_DOCUMENT",
    #                 title: "RubyLLM docs"
    #
    # +model:+ selects the embedding model and defaults to the
    # configured +default_embedding_model+. +provider:+ forces a specific
    # provider, and <tt>assume_model_exists: true</tt> skips the model
    # registry check. +context:+ supplies a Context whose configuration
    # is used instead of the global one. +dimensions:+ requests a
    # specific vector size on models that support it. +task_type:+ names
    # the embedding task in the provider's own vocabulary: Vertex AI and
    # Gemini take values such as <tt>"RETRIEVAL_QUERY"</tt> or
    # <tt>"RETRIEVAL_DOCUMENT"</tt>, while Bedrock Cohere takes an input
    # type such as <tt>"search_document"</tt>. +title:+ labels the
    # document on Vertex AI and Gemini retrieval tasks. Providers that
    # have no task concept ignore both. +provider_options:+ takes options
    # in the provider's request vocabulary and merges them into the
    # request as-is. +metadata:+ is not sent to the provider; it is
    # attached to the emitted +embedding.ruby_llm+ instrumentation event.
    def self.embed(text, # rubocop:disable Metrics/ParameterLists
                   model: nil,
                   provider: nil,
                   assume_model_exists: false,
                   context: nil,
                   dimensions: nil,
                   task_type: nil,
                   title: nil,
                   provider_options: {},
                   metadata: nil)
      config = context&.config || RubyLLM.config
      model ||= config.default_embedding_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_model_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      payload = {
        provider: provider_instance.slug,
        provider_class: provider_instance.class.display_name,
        model: model_id,
        model_info: model,
        input: text,
        dimensions: dimensions,
        task_type: task_type,
        title: title,
        provider_options: provider_options,
        metadata: metadata
      }

      RubyLLM.instrument('embedding.ruby_llm', payload, config: config) do |event|
        result = provider_instance.embed(text, model:, dimensions:, task_type:, title:, provider_options:)
        event[:result] = result
        event[:response_model] = result.model
        event[:input_tokens] = result.input_tokens
        event[:embedding_dimensions] = vector_dimensions(result.vectors)
        event[:embedding_count] = embedding_count(result.vectors)
        result
      end
    end

    private_class_method def self.vector_dimensions(vectors) # :nodoc:
      vector = vectors.first.is_a?(Array) ? vectors.first : vectors
      vector.length
    end

    private_class_method def self.embedding_count(vectors) # :nodoc:
      vectors.first.is_a?(Array) ? vectors.size : 1
    end
  end
end
