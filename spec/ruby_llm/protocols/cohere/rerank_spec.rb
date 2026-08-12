# frozen_string_literal: true

require 'spec_helper'

# Fixtures are the request and response example published at
# https://docs.cohere.com/reference/rerank, copied verbatim.
RSpec.describe RubyLLM::Protocols::Cohere::Rerank do
  let(:protocol) { Object.new.extend(described_class) }

  let(:documents) do
    [
      'Carson City is the capital city of the American state of Nevada.',
      'The Commonwealth of the Northern Mariana Islands is a group of islands in the Pacific Ocean.',
      'Capitalization or capitalisation in English grammar is the use of a capital letter.',
      'Washington, D.C. is the capital of the United States. It is a federal district.',
      'Capital punishment has existed in the United States since before the United States was a country.'
    ]
  end

  let(:body) do
    {
      'results' => [
        { 'index' => 3, 'relevance_score' => 0.999071 },
        { 'index' => 4, 'relevance_score' => 0.7867867 },
        { 'index' => 0, 'relevance_score' => 0.32713068 }
      ],
      'id' => '07734bd2-2473-4f07-94e1-0d9f0e6843cf',
      'meta' => { 'api_version' => { 'version' => '2' }, 'billed_units' => { 'search_units' => 1 } }
    }
  end

  describe '#rerank_url' do
    it 'posts to the v2 rerank endpoint' do
      expect(protocol.send(:rerank_url)).to eq('v2/rerank')
    end
  end

  describe '#render_rerank_payload' do
    it 'renders the query, documents, and top_n' do
      payload = protocol.send(
        :render_rerank_payload,
        'What is the capital of the United States?', documents, model: 'rerank-v4.0-pro', top_n: 3
      )

      expect(payload).to eq(
        model: 'rerank-v4.0-pro',
        query: 'What is the capital of the United States?',
        documents: documents,
        top_n: 3
      )
    end

    it 'omits top_n when the caller wants every result' do
      payload = protocol.send(:render_rerank_payload, 'q', documents, model: 'rerank-v3.5')

      expect(payload).not_to have_key(:top_n)
    end

    it 'merges provider options such as max_tokens_per_doc' do
      payload = protocol.send(
        :render_rerank_payload, 'q', documents,
        model: 'rerank-v3.5', provider_options: { max_tokens_per_doc: 1024 }
      )

      expect(payload[:max_tokens_per_doc]).to eq(1024)
    end
  end

  describe '#parse_rerank_response' do
    it 'orders results by relevance' do
      rerank = protocol.send(:parse_rerank_response, response, model: 'rerank-v4.0-pro', documents: documents)

      expect(rerank.results.map(&:index)).to eq([3, 4, 0])
      expect(rerank.results.first.score).to eq(0.999071)
      expect(rerank.model).to eq('rerank-v4.0-pro')
    end

    # Cohere returns positions only, so the text comes back from the request.
    it 'resolves each ranked document from the documents that were sent' do
      rerank = protocol.send(:parse_rerank_response, response, model: 'rerank-v4.0-pro', documents: documents)

      expect(rerank.results.first.document).to eq(documents[3])
      expect(rerank.results.last.document).to eq(documents[0])
    end

    it 'reads billed input tokens when Cohere reports them' do
      body['meta']['tokens'] = { 'input_tokens' => 42 }

      rerank = protocol.send(:parse_rerank_response, response, model: 'rerank-v4.0-pro', documents: documents)

      expect(rerank.tokens.input).to eq(42)
    end
  end

  def response
    instance_double(Faraday::Response, body: body)
  end
end
