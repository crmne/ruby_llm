# frozen_string_literal: true

module RubyLLM
  # Represents a single rerank result with index, relevance score, and document
  class RerankResult
    attr_reader :index, :relevance_score, :document

    def initialize(index:, relevance_score:, document:)
      @index = index
      @relevance_score = relevance_score
      @document = document
    end

    def self.from_hash(hash)
      new(
        index: hash[:index],
        relevance_score: hash[:relevance_score],
        document: hash[:document]
      )
    end
  end
end
