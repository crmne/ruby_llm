# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Rerank do
  include_context 'with configured RubyLLM'

  let(:test_query) { 'What is Ruby programming?' }
  let(:test_documents) do
    [
      'Ruby is a dynamic, object-oriented programming language',
      'Cooking recipes for beginners',
      'Ruby was created by Yukihiro Matsumoto in 1995',
      'Weather patterns in different climates',
      'Ruby on Rails is a popular web framework for Ruby'
    ]
  end

  describe 'basic functionality' do
    RERANK_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} can rerank documents" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        rerank = described_class.rank(test_query, test_documents, model: model)

        expect(rerank.results).to be_an(Array)
        expect(rerank.results).not_to be_empty
        expect(rerank.results.first).to be_a(RubyLLM::RerankResult)
        expect(rerank.model).to eq(model)
        expect(rerank.search_units).to be >= 0
      end

      it "#{provider}/#{model} returns results sorted by relevance" do
        rerank = described_class.rank(test_query, test_documents, model: model)

        scores = rerank.results.map(&:relevance_score)
        expect(scores).to eq(scores.sort.reverse)
      end

      it "#{provider}/#{model} includes document indices and content" do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
        rerank = described_class.rank(test_query, test_documents, model: model)

        rerank.results.each do |result|
          expect(result.index).to be_a(Integer)
          expect(result.index).to be_between(0, test_documents.length - 1)
          expect(result.document).to be_a(String)
          expect(test_documents).to include(result.document)
          expect(result.relevance_score).to be_a(Float)
        end
      end

      it "#{provider}/#{model} can limit results with top_n" do
        top_n = 2
        rerank = described_class.rank(test_query, test_documents, model: model, top_n: top_n)

        expect(rerank.results.length).to eq(top_n)
      end

      it "#{provider}/#{model} raises error for empty document arrays" do
        expect {
          described_class.rank(test_query, [], model: model)
        }.to raise_error(ArgumentError, 'No documents provided for reranking')
      end

      it "#{provider}/#{model} can handle max_tokens_per_doc parameter" do # rubocop:disable RSpec/MultipleExpectations
        rerank = described_class.rank(test_query, test_documents, model: model, max_tokens_per_doc: 100)

        expect(rerank.results).to be_an(Array)
        expect(rerank.model).to eq(model)
      end
    end
  end
end
