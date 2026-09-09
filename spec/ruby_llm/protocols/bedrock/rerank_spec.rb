# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Bedrock::Rerank do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:bedrock, :bedrock_rerank) }
  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider, RubyLLM.models.find(model, provider: :bedrock)) }
  let(:documents) { ['Bananas are fruit.', 'Ruby is a programming language.'] }
  let(:endpoint) { 'https://bedrock-agent-runtime.us-west-2.amazonaws.com/rerank' }

  it 'selects the dedicated reranker and signs the agent-runtime request for its model ARN' do
    request = stub_request(:post, endpoint).with do |req|
      payload = JSON.parse(req.body)
      expect(payload['queries']).to eq([{ 'type' => 'TEXT', 'textQuery' => { 'text' => 'Ruby language' } }])
      expect(payload.dig('rerankingConfiguration', 'bedrockRerankingConfiguration')).to include(
        'numberOfResults' => 1,
        'modelConfiguration' => { 'modelArn' => "arn:aws:bedrock:us-west-2::foundation-model/#{model}" }
      )
      expect(payload['sources'].last.dig('inlineDocumentSource', 'textDocument', 'text')).to eq(documents.last)
      expect(req.headers['Authorization']).to include('/us-west-2/bedrock/aws4_request')
    end.to_return_json(body: { results: [{ index: 1, relevanceScore: 0.91 }] })

    result = RubyLLM.rerank('Ruby language', documents, model:, provider: :bedrock, top_n: 1)

    expect(result.results.first).to have_attributes(index: 1, document: documents.last, score: 0.91)
    expect(result.tokens.input).to be_nil
    expect(result.cost.total).to be_nil
    expect(request).to have_been_requested.once
  end

  it 'consumes every result page while preserving original document indices and raw pages' do
    pages = [{ results: [{ index: 1, relevanceScore: 0.9 }], nextToken: 'page2' },
             { results: [{ index: 0, relevanceScore: 0.1 }] }]
    stub_request(:post, endpoint).to_return_json(body: pages.first).then.to_return_json(body: pages.last)

    result = protocol.rerank('Ruby language', documents, model:)

    expect(result.results.map(&:index)).to eq([1, 0])
    expect(result.results.map(&:document)).to eq(documents.reverse)
    expect(result.raw).to eq(JSON.parse(JSON.generate(pages)))
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq(%i[succeeded succeeded])
    expect(a_request(:post, endpoint).with { |request| JSON.parse(request.body)['nextToken'] == 'page2' })
      .to have_been_made.once
  end

  it 'keeps a successful page succeeded when a later request fails without inventing usage' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    stub_request(:post, endpoint)
      .to_return_json(body: { results: [{ index: 1, relevanceScore: 0.9 }], nextToken: 'page2' })
      .then.to_return_json(status: 500, body: { message: 'Unable to read the next page' })

    expect { context.rerank('Ruby language', documents, model:, provider: :bedrock) }
      .to raise_error(RubyLLM::ServerError)

    attempts = instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
    expect(attempts.map { |attempt| attempt[:status] }).to eq(%i[succeeded failed])
    expect(attempts.map { |attempt| attempt[:tokens].to_h }).to eq([{}, {}])
    expect(attempts.map { |attempt| attempt[:cost].total }).to eq([nil, nil])
  end

  it 'renders JSON documents and model-specific parameters without discarding their original values' do
    document = { title: 'Ruby', body: 'A programming language' }
    fields = { rerankingConfiguration: { bedrockRerankingConfiguration: {
      modelConfiguration: { additionalModelRequestFields: { max_tokens_per_doc: 128 } }
    } } }
    payload = protocol.send(:render_rerank_payload, 'Ruby', [document], model:, top_n: nil, provider_options: fields)
    expect(payload[:sources]).to eq([{ type: 'INLINE',
                                       inlineDocumentSource: { type: 'JSON', jsonDocument: document } }])
    expect(payload.dig(:rerankingConfiguration, :bedrockRerankingConfiguration, :modelConfiguration)).to include(
      additionalModelRequestFields: { max_tokens_per_doc: 128 }
    )
  end

  it 'rejects unsupported inputs and models before making a request' do
    [[], Array.new(1001, 'text'), [1]].each do |input|
      expect { protocol.rerank('Ruby', input, model:) }.to raise_error(ArgumentError, /documents/)
    end
    expect { protocol.rerank('', documents, model:) }.to raise_error(ArgumentError, /query/)
    expect { protocol.rerank('Ruby', documents, model:, top_n: 0) }.to raise_error(ArgumentError, /top_n/)
    expect { protocol.rerank('Ruby', documents, model: model_for(:bedrock)) }
      .to raise_error(RubyLLM::Error, /not supported/)
  end

  it 'rejects repeated page tokens and invalid provider result indices' do
    stub_request(:post, endpoint).to_return_json(body: { results: [], nextToken: 'same' })
    expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /repeated pagination/)
    stub_request(:post, endpoint).to_return_json(body: { results: [{ index: 9, relevanceScore: 1 }] })
    expect { protocol.rerank('Ruby', documents, model:) }.to raise_error(RubyLLM::Error, /invalid document index/)
  end

  it 'reranks actual documents with Amazon Rerank and leaves unreported usage unknown', :live do
    result = RubyLLM.rerank('Ruby language', documents, model:, provider: :bedrock, top_n: 1)
    expect(result.results.length).to eq(1)
    expect(result.results.first).to have_attributes(index: 1, document: documents.last, score: be_between(0, 1))
    expect(result.tokens.input).to be_nil
    expect(result.cost.total).to be_nil
  end
end
