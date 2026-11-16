# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI do
  include_context 'with configured RubyLLM'

  let(:documents) { ['Paris is the capital of France.', 'Ruby is a programming language.'] }

  def rerank_on(api_base, **config)
    context = RubyLLM.context do |settings|
      settings.openai_api_base = api_base
      config.each { |option, value| settings.public_send(:"#{option}=", value) }
    end
    context.rerank('what is ruby', documents, model: 'bge-reranker-v2-m3', provider: :openai,
                                              assume_model_exists: true)
  end

  [nil, :responses, :chat_completions].each do |chat_protocol|
    it "reranks on an OpenAI-compatible server with openai_protocol #{chat_protocol.inspect}" do
      stub = stub_request(:post, 'http://localhost:8080/v1/rerank')
             .with(body: { model: 'bge-reranker-v2-m3', query: 'what is ruby', documents: documents })
             .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                        body: { results: [{ index: 1, relevance_score: 0.98 },
                                          { index: 0, relevance_score: -10.2 }] }.to_json)

      rerank = rerank_on('http://localhost:8080/v1', openai_protocol: chat_protocol)

      expect(rerank.results.map { |result| [result.index, result.document, result.score] })
        .to eq([[1, documents[1], 0.98], [0, documents[0], -10.2]])
      expect(stub).to have_been_requested.once
    end
  end

  it 'refuses to rerank on OpenAI itself, which has no rerank endpoint' do
    [nil, 'https://api.openai.com/v1', 'https://eu.api.openai.com/v1', 'https://api.openai.com./v1'].each do |api_base|
      expect { rerank_on(api_base) }
        .to raise_error(RubyLLM::Error, /OpenAI doesn't support reranking.*openai_api_base/)
    end
    expect(a_request(:any, /openai\.com/)).not_to have_been_made
  end
end
