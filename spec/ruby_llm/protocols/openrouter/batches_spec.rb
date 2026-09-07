# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::OpenRouter::Batches do
  let(:context) { RubyLLM.context { |config| config.openrouter_api_key = 'test' } }
  let(:model) { model_for(:openrouter) }
  let(:embedding_model) { model_for(:openrouter, :embedding) }
  let(:endpoint) { 'https://openrouter.ai/api/beta/batches' }

  def batch_data(model:, results: [], api: '/v1/chat/completions', status: 'completed', count: results.size)
    { id: 'batch-ruby', status:, endpoint: api, model:, request_counts: { total: count }, results: }
  end

  def response_row(id, body)
    { custom_id: id, response: { status_code: 200, body: }, error: nil }
  end

  def embedding_row(id, vectors)
    rows = vectors.each_with_index.map { |vector, index| { index:, embedding: vector } }.reverse
    response_row(id, { model: embedding_model, data: rows, usage: { prompt_tokens: 4, cost: 0.0001 } })
  end

  it 'submits inline text requests in the required key order and preserves the resolved model ID' do
    chat = context.chat(model:, provider: :openrouter).ask_later('Reply Ruby.')
    request = stub_request(:post, endpoint).with do |req|
      data = JSON.parse(req.body)
      expect(data.keys).to eq(%w[endpoint model requests])
      expect(data['endpoint']).to eq('/v1/chat/completions')
      expect(data['model']).to eq(chat.model.id)
      expect(data['requests'].first['custom_id']).to eq('0')
      expect(data['requests'].first['body']).not_to have_key('stream')
    end.to_return_json(body: batch_data(model: chat.model.id, status: 'validating', count: 1))

    batch = RubyLLM.batch(chat)
    expect(batch).to have_attributes(id: 'batch-ruby', status: :pending, raw_status: 'validating')
    expect(request).to have_been_requested.once
    expect(a_request(:post, /files/)).not_to have_been_made
  end

  it 'restores scalar and array embedding results in request and vector order' do
    requests = ['Ruby', ['Rails'], %w[AI Ruby]].map do |text|
      context.embed_later(text, model: embedding_model, provider: :openrouter)
    end
    rows = [embedding_row('2:array', [[5, 6], [7, 8]]), embedding_row('0', [[1, 2]]),
            embedding_row('1:array', [[3, 4]])]
    data = batch_data(model: embedding_model, api: '/v1/embeddings', results: rows)
    stub_request(:post, endpoint).with do |req|
      expect(JSON.parse(req.body)['requests'].map { |row| row['custom_id'] }).to eq(['0', '1:array', '2:array'])
    end.to_return_json(body: data)
    stub_request(:get, "#{endpoint}/batch-ruby").to_return_json(body: data)
    batch = RubyLLM.batch(requests)
    expect(batch.results.map(&:vectors)).to eq([[1, 2], [[3, 4]], [[5, 6], [7, 8]]])
    restored = RubyLLM::Batch.find(batch.id, provider: :openrouter, context:)
    expect(restored.results.map(&:vectors)).to eq(batch.results.map(&:vectors))
    expect(restored.tokens.input).to eq(12)
    expect(restored.cost.total).to be_within(0.0000001).of(0.0003)
  end

  it 'normalizes Responses results and preserves per-request failures after a fresh find' do
    body = { model:, status: 'completed', output: [{ type: 'message', role: 'assistant',
                                                     content: [{ type: 'output_text', text: 'Ruby.' }] }],
             usage: { input_tokens: 2, output_tokens: 3, cost: 0.0001 } }
    rows = [{ custom_id: '1', response: nil, error: { message: 'Unavailable' } }, response_row('0', body)]
    data = batch_data(model:, api: '/v1/responses', results: rows)
    stub_request(:get, "#{endpoint}/batch-ruby").to_return_json(body: data)
    batch = RubyLLM::Batch.find('batch-ruby', provider: :openrouter, context:)

    expect(batch.results.first).to have_attributes(content: 'Ruby.', finish_reason: :stop)
    expect(batch.results.last).to be_nil
    expect(batch.statuses).to eq(%i[succeeded failed])
    expect(batch.tokens).to have_attributes(input: 2, output: 3)
  end

  it 'rejects multimodal requests and unsupported embedding options before submitting' do
    image = context.chat(model:, provider: :openrouter).ask_later('Describe.', with: 'spec/fixtures/ruby.png')
    embeddings = context.embed_later('Ruby', model: embedding_model, provider: :openrouter)
    allow(embeddings).to receive(:render).and_return(model: embedding_model, input: 'Ruby', input_type: 'query')
    [image, embeddings].each do |request|
      expect { RubyLLM.batch(request) }.to raise_error(ArgumentError, /text/)
    end
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'keeps missing results pending and rejects duplicate IDs and unavailable cancellation' do
    data = batch_data(model:, status: 'in_progress', results: nil, count: 2)
    stub_request(:get, "#{endpoint}/batch-ruby").to_return_json(body: data)
    batch = RubyLLM::Batch.find('batch-ruby', provider: :openrouter, context:)
    expect(batch.results).to eq([nil, nil])
    expect(batch.status).to eq(:pending)
    expect { batch.cancel }.to raise_error(RubyLLM::Error, /does not expose batch cancellation/)
    rows = [embedding_row('0', [[1, 2]]), embedding_row('0', [[3, 4]])]
    stub_request(:get, "#{endpoint}/batch-ruby")
      .to_return_json(body: batch_data(model: embedding_model, results: rows, api: '/v1/embeddings'))
    expect { batch.results }.to raise_error(RubyLLM::Error, /duplicate batch request IDs/)
  end

  it 'does not repeat a submission whose outcome is uncertain' do
    context.config.max_retries = 2
    request = stub_request(:post, endpoint).to_return(status: 502, body: '{"error":{"message":"Unavailable"}}',
                                                      headers: { 'Content-Type' => 'application/json' })
    chat = context.chat(model:, provider: :openrouter).ask_later('Ruby.')
    expect { RubyLLM.batch(chat) }.to raise_error(RubyLLM::Error, /Unavailable/)
    expect(request).to have_been_requested.once
  end

  it 'uses the reported aggregate invoice without assigning that amount to individual results' do
    data = batch_data(model: embedding_model, api: '/v1/embeddings', results: [embedding_row('0', [[1, 2]])])
           .merge(usage: { cost: 0.00004, prompt_tokens: 99 })
    stub_request(:get, "#{endpoint}/batch-ruby").to_return_json(body: data)
    batch = RubyLLM::Batch.find('batch-ruby', provider: :openrouter, context:)

    expect(batch.reported_cost).to be_a(RubyLLM::Cost)
    expect(batch.cost.total).to eq(0.00004)
    expect(batch.results.first.cost.total).to eq(0.0001)
    expect(batch.tokens.input).to eq(4)
  end
end
