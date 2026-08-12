# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Rerank, :live do
  describe 'payload rendering' do
    it 'renders the Jina-style rerank request' do
      protocol = RubyLLM::Providers::OpenRouter::ChatCompletions.new(
        RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
      )
      payload = protocol.send(:render_rerank_payload, 'what is ruby', %w[a b],
                              model: 'voyageai/rerank-2.5-lite', top_n: 2)

      expect(payload).to eq(model: 'voyageai/rerank-2.5-lite', query: 'what is ruby',
                            documents: %w[a b], top_n: 2)
    end

    it 'raises clearly for providers without a rerank endpoint' do
      expect do
        RubyLLM.rerank('query', ['doc'], model: 'claude-haiku-4-5', provider: :anthropic)
      end.to raise_error(RubyLLM::Error, /doesn't support reranking/)
    end
  end

  describe 'reranking' do
    context 'with cohere/rerank-v3.5', if: provider_recorded?(:cohere) do
      it 'orders documents by relevance and resolves them from the request' do
        rerank = RubyLLM.rerank(
          'What is the capital of the United States?',
          ['Carson City is the capital city of the American state of Nevada.',
           'Washington, D.C. is the capital of the United States. It is a federal district.'],
          model: 'rerank-v3.5', provider: :cohere
        )

        expect(rerank.results.first.document).to include('Washington')
        expect(rerank.results.first.score).to be > rerank.results.last.score
        expect(rerank.results.map(&:index)).to contain_exactly(0, 1)
      end

      it 'limits results with top_n' do
        rerank = RubyLLM.rerank(
          'ruby',
          ['Ruby is a programming language', 'Paris is in France', 'Rails is a Ruby framework'],
          model: 'rerank-v3.5', provider: :cohere, top_n: 2
        )

        expect(rerank.results.length).to eq(2)
      end
    end

    context 'with openrouter/voyageai/rerank-2.5-lite' do
      it 'orders documents by relevance and reports the exact cost' do
        rerank = RubyLLM.rerank(
          'what is ruby',
          ['Paris is the capital of France', 'Ruby is a programming language created by Matz'],
          model: 'voyageai/rerank-2.5-lite', provider: :openrouter, assume_model_exists: true
        )

        expect(rerank.results.first.document).to include('Ruby')
        expect(rerank.results.first.score).to be > rerank.results.last.score
        expect(rerank.results.map(&:index)).to contain_exactly(0, 1)
        expect(rerank.tokens.reported_cost).to be_positive
      end
    end
  end
end
