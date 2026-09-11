# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::EmbeddingBatches do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.gemini_api_key = 'test'
    RubyLLM::Providers::Gemini.new(config)
  end
  let(:model) { RubyLLM.models.find(model_for(:gemini, :embedding), provider: :gemini) }
  let(:protocol) { provider.protocols.fetch(:gemini).new(provider, model) }

  def batch_request(text, id: '0')
    { custom_id: id, model: model.id, payload: provider.render_embedding(text, model:, dimensions: 64) }
  end

  def inline_response(request, vector)
    { 'metadata' => request.fetch(:metadata).stringify_keys,
      'response' => { 'embedding' => { 'values' => vector }, 'usageMetadata' => { 'promptTokenCount' => 2 } } }
  end

  it 'stages scalar input as embedContent and arrays as batchEmbedContents payloads' do
    scalar = batch_request('Ruby')[:payload]
    array = batch_request(['Ruby'])[:payload]

    expect(scalar).to include(content: { parts: [{ text: 'Ruby' }] }, outputDimensionality: 64)
    expect(scalar).not_to have_key(:requests)
    expect(array.fetch(:requests)).to eq([scalar])
  end

  it 'submits an asynchronous embedding batch with explicit result correlation metadata' do
    response = instance_double(Faraday::Response, body: {
                                 'name' => 'batches/abc', 'metadata' => { 'state' => 'BATCH_STATE_PENDING' }
                               })
    allow(provider.connection).to receive(:post).and_return(response)

    batch = protocol.create_batch([batch_request('Ruby'), batch_request(%w[Python Rust], id: '1')])

    expect(batch).to include(id: 'batches/abc', completed: false)
    expect(provider.connection).to have_received(:post).with(
      "models/#{model.id}:asyncBatchEmbedContent",
      { batch: { displayName: a_string_starting_with('ruby_llm_'), inputConfig: {
        requests: { requests: [
          hash_including(metadata: { custom_id: '0', model: model.id, array_input: false,
                                     embedding_index: 0, embedding_count: 1 }),
          hash_including(metadata: { custom_id: '1', model: model.id, array_input: true,
                                     embedding_index: 0, embedding_count: 2 }),
          hash_including(metadata: { custom_id: '1', model: model.id, array_input: true,
                                     embedding_index: 1, embedding_count: 2 })
        ] }
      } } }, idempotent: false
    )
  end

  it 'preserves scalar, one-element array, and multiple input shapes with reordered results' do
    inputs = ['Ruby', ['Rails'], %w[Python Rust]].each_with_index.flat_map do |text, index|
      protocol.send(:embedding_batch_requests, batch_request(text, id: index.to_s), model.id)
    end
    responses = inputs.each_with_index.map { |request, index| inline_response(request, [index.to_f, 0.2]) }.reverse

    results = protocol.send(:parse_embedding_batch_results, responses).to_h

    expect(results.fetch(0).vectors).to eq([0.0, 0.2])
    expect(results.fetch(1).vectors).to eq([[1.0, 0.2]])
    expect(results.fetch(2).vectors).to eq([[2.0, 0.2], [3.0, 0.2]])
    expect(results.fetch(2).tokens.input).to eq(4)
  end

  it 'reads embedding output when collecting a batch from a fresh protocol instance' do
    input = protocol.send(:embedding_batch_requests, batch_request('Ruby'), model.id).first
    body = { 'response' => { 'inlinedEmbedContentResponses' => {
      'inlinedResponses' => [inline_response(input, [0.1, 0.2])]
    } } }
    allow(provider.connection).to receive(:get).with('batches/abc')
                                               .and_return(instance_double(Faraday::Response, body:))

    result = provider.protocols.fetch(:gemini).new(provider).batch_results('batches/abc').first.last

    expect(result).to be_a(RubyLLM::Embedding)
    expect(result.model).to eq(model.id)
    expect(result.vectors).to eq([0.1, 0.2])
  end

  it 'keeps incomplete grouped results pending and reports per-item errors' do
    inputs = protocol.send(:embedding_batch_requests, batch_request(%w[Ruby Rails]), model.id)
    success = inline_response(inputs.first, [0.1])
    failure = { 'metadata' => inputs.last.fetch(:metadata).stringify_keys,
                'error' => { 'message' => 'Input too long' } }
    allow(RubyLLM.logger).to receive(:warn)

    expect(protocol.send(:parse_embedding_batch_results, [success])).to be_empty
    expect(protocol.send(:parse_embedding_batch_results, [success, failure])).to eq([[0, nil, :failed]])
  end

  it 'rejects a duplicated embedding_index instead of silently pairing the wrong vector' do
    inputs = protocol.send(:embedding_batch_requests, batch_request(%w[Ruby Rails]), model.id)
    # Both responses claim position 0 (position 1's response is missing), but
    # the group is still the expected size -- the only way this can be
    # detected is by checking the positions themselves, not just the count.
    duplicated = inputs.first.fetch(:metadata)
    responses = [inline_response(inputs.first.merge(metadata: duplicated), [1.0]),
                 inline_response(inputs.last.merge(metadata: duplicated), [2.0])]
    allow(RubyLLM.logger).to receive(:warn)

    expect(protocol.send(:parse_embedding_batch_results, responses)).to eq([[0, nil, :failed]])
  end

  it 'hydrates staged embedding requests and restores a completed batch by id' do
    allow(RubyLLM::Providers::Gemini).to receive(:new).and_return(provider)
    context = RubyLLM.context { |config| config.gemini_api_key = 'test' }
    requests = ['Ruby', ['Rails'], %w[Python Rust]].map do |text|
      context.embed_later(text, model: model.id, provider: :gemini)
    end
    output = requests.each_with_index.flat_map do |request, index|
      inputs = protocol.send(:embedding_batch_requests, { custom_id: index.to_s, payload: request.render }, model.id)
      inputs.map { |input| inline_response(input, [0.1, 0.2]) }
    end
    metadata = { '@type' => 'type.googleapis.com/google.ai.generativelanguage.v1main.EmbedContentBatch',
                 'batchStats' => { 'requestCount' => '4' } }
    pending = { 'name' => 'batches/abc', 'metadata' => metadata.merge('state' => 'BATCH_STATE_PENDING') }
    completed = { 'name' => 'batches/abc', 'metadata' => metadata.merge('state' => 'BATCH_STATE_SUCCEEDED'),
                  'response' => { 'inlinedResponses' => { 'inlinedResponses' => output.reverse } } }
    allow(provider.connection).to receive(:post).and_return(instance_double(Faraday::Response, body: pending))
    allow(provider.connection).to receive(:get).with('batches/abc')
                                               .and_return(instance_double(Faraday::Response, body: completed))

    batch = RubyLLM.batch(requests).refresh
    expect(batch).to be_succeeded
    expect(batch.results.map(&:vectors)).to eq([[0.1, 0.2], [[0.1, 0.2]], [[0.1, 0.2], [0.1, 0.2]]])
    expect(requests.map(&:result)).to eq(batch.results)
    expect(RubyLLM::Batch.find(batch.id, provider: :gemini, context:).results.map(&:vectors))
      .to eq(batch.results.map(&:vectors))
  end

  it 'rejects mixed operations and empty embedding inputs before submission' do
    expect do
      protocol.create_batch([batch_request('Ruby'), { model: model.id, payload: { contents: [] } }])
    end.to raise_error(RubyLLM::Error, /chat or embedding requests/)
    expect { protocol.create_batch([batch_request([])]) }.to raise_error(ArgumentError, /at least one text/)
  end

  it 'submits, retrieves, and cancels an asynchronous embedding batch', :live do
    request = RubyLLM.embed_later('Ruby', model: model_for(:gemini, :embedding), provider: :gemini, dimensions: 64)
    batch = RubyLLM.batch([request])
    restored = RubyLLM::Batch.find(batch.id, provider: :gemini)

    expect(restored.id).to eq(batch.id)
    expect(restored.cancel).to equal(restored)
    expect(restored).not_to be_failed
  end
end
