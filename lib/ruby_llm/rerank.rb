# frozen_string_literal: true

module RubyLLM
  # Core reranking interface. Provides a clean way to generate rerankings
  # for a given query and set of documents using various provider models.
  class Rerank
    attr_reader :results, :model, :search_units

    def initialize(results:, model:, search_units:)
      @results = results.sort_by { |r| -r.relevance_score }
      @model = model
      @search_units = search_units
    end

    def self.rank(query, # rubocop:disable Metrics/ParameterLists
                  documents,
                  model: nil,
                  provider: nil,
                  assume_model_exists: false,
                  context: nil,
                  top_n: nil,
                  max_tokens_per_doc: nil)
      raise ArgumentError, 'No documents provided for reranking' if documents.empty?

      config = context&.config || RubyLLM.config
      model ||= config.default_rerank_model
      model, provider = Models.resolve(model, provider: provider, assume_exists: assume_model_exists)
      model_id = model.id

      provider = Provider.for(model_id) if provider.nil?
      connection = context ? context.connection_for(provider) : provider.connection(config)
      provider.rank(query, documents, model: model_id, connection:, top_n:, max_tokens_per_doc:)
    end
  end
end
