# frozen_string_literal: true

module RubyLLM
  # A Rerank is the result of ordering documents by relevance to a query.
  # RubyLLM.rerank returns one:
  #
  #   rerank = RubyLLM.rerank("what is ruby",
  #                           ["Ruby is a programming language", "Paris is in France"],
  #                           model: "voyageai/rerank-2.5-lite", provider: :openrouter)
  #   rerank.results.first.document # => "Ruby is a programming language"
  #   rerank.results.first.score    # => 0.80078125
  #
  class Rerank
    include Support::Inspectable
    include Accounting::Usage::Result
    include Accounting::Usage::ModelInfo

    # One reranked document: its +index+ in the input array, the
    # +document+ text, and the provider's relevance +score+.
    Result = Struct.new(:index, :document, :score, keyword_init: true)

    # The reranked results, most relevant first, as an array of Result.
    attr_reader :results

    # The id of the model that ranked the documents, as a String.
    attr_reader :model

    # The raw provider response body.
    attr_reader :raw

    def initialize(results:, model:, raw: nil, input_tokens: nil, reported_cost: nil) # :nodoc:
      @results = results
      @model = model
      @raw = raw
      @input_tokens = input_tokens
      @reported_cost = reported_cost
    end

    # Returns usage aggregated across every provider attempt.
    def tokens
      return ruby_llm_usage_tokens unless ruby_llm_usage_entries.empty?

      Tokens.new(input: @input_tokens, reported_cost: @reported_cost)
    end

    # Returns the rerank cost across every provider attempt.
    def cost
      return ruby_llm_usage_cost unless ruby_llm_usage_entries.empty?

      Cost.new(tokens:, model: model_info, category: :embeddings)
    end

    def inspect_attributes # :nodoc:
      { model: model, results: results.length }
    end

    # Ranks +documents+ (an array of strings) by relevance to +query+ and
    # returns a Rerank. +model:+ is required; rerank catalogs are
    # provider-specific and have no cross-provider default. +top_n:+
    # limits how many results come back. +provider_options:+ merges
    # options into the request in the provider's vocabulary.
    # +owner:+ attributes the usage to a record, such as a user, and wins
    # over RubyLLM.with_usage_owner.
    #
    #   RubyLLM.rerank "what is ruby", docs, model: "voyageai/rerank-2.5-lite", provider: :openrouter
    #
    def self.rerank(query, documents,
                    model:,
                    provider: nil,
                    assume_model_exists: false,
                    context: nil,
                    top_n: nil,
                    provider_options: {},
                    metadata: nil,
                    owner: nil)
      Accounting::Operation.new(
        'rerank', model, category: :embeddings, provider:, assume_model_exists:, context:, owner:
      ).run(query:, document_count: documents.length, top_n:, provider_options:,
            metadata:) do |provider_instance, model|
        provider_instance.rerank(query, documents, model:, top_n:, provider_options:)
      end
    end
  end
end
