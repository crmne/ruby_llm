# frozen_string_literal: true

require 'spec_helper'

# The Jina-style rerank endpoint several OpenAI-compatible providers serve
# (OpenRouter, GPUStack) with identical request and response shapes.
RSpec.describe RubyLLM::Protocols::ChatCompletions::Rerank do
  let(:protocol) { Object.new.extend(described_class) }

  let(:documents) { %w[doc0 doc1 doc2] }

  let(:body) do
    {
      'model' => 'voyageai/rerank-2.5-lite',
      'results' => [
        { 'index' => 1, 'relevance_score' => 0.91 },
        { 'index' => 0, 'relevance_score' => 0.12 }
      ],
      'usage' => { 'total_tokens' => 7, 'cost' => 0.0001 }
    }
  end

  def response
    instance_double(Faraday::Response, body: body)
  end

  describe '#rerank_url' do
    it 'posts to the shared rerank endpoint' do
      expect(protocol.send(:rerank_url)).to eq('rerank')
    end
  end

  describe '#parse_rerank_response' do
    it 'resolves each ranked document from the documents that were sent, in relevance order' do
      rerank = protocol.send(:parse_rerank_response, response, model: 'voyageai/rerank-2.5-lite', documents: documents)

      expect(rerank.results.map(&:document)).to eq(%w[doc1 doc0])
      expect(rerank.results.first.score).to eq(0.91)
    end

    it 'reports the exact cost when the provider returns one' do
      rerank = protocol.send(:parse_rerank_response, response, model: 'voyageai/rerank-2.5-lite', documents: documents)

      expect(rerank.tokens.reported_cost).to eq(0.0001)
    end

    # A negative index is a valid Ruby array index (documents[-1] is the
    # last document), so an unvalidated index would silently substitute
    # the wrong document instead of raising.
    it 'rejects a negative document index instead of wrapping to the last document' do
      body['results'] = [{ 'index' => -1, 'relevance_score' => 0.9 }]

      expect do
        protocol.send(:parse_rerank_response, response, model: 'voyageai/rerank-2.5-lite', documents: documents)
      end
        .to raise_error(RubyLLM::Error, /invalid document index/)
    end

    it 'rejects an out-of-range document index instead of returning a nil document' do
      body['results'] = [{ 'index' => documents.length, 'relevance_score' => 0.9 }]

      expect do
        protocol.send(:parse_rerank_response, response, model: 'voyageai/rerank-2.5-lite', documents: documents)
      end
        .to raise_error(RubyLLM::Error, /invalid document index/)
    end
  end
end
