# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::VertexAI::EmbeddingPrediction do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:vertexai, :embedding) }
  let(:provider) { RubyLLM::Providers::VertexAI.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider) }
  let(:job_name) { 'projects/test-project/locations/us-central1/batchPredictionJobs/123' }
  let(:output_uri) { 'gs://ruby-llm-batches/test/output' }

  before do |example|
    next if example.metadata[:live]

    RubyLLM.config.vertexai_location = 'us-central1'
    RubyLLM.config.vertexai_project_id = 'test-project'
    RubyLLM.config.vertexai_batch_gcs_uri = 'gs://ruby-llm-batches/test'
    allow(provider).to receive(:headers).and_return('Authorization' => 'Bearer token')
  end

  def job(state: 'JOB_STATE_SUCCEEDED', model_id: model)
    { 'name' => job_name, 'state' => state,
      'model' => "publishers/google/models/#{model_id}",
      'labels' => { 'ruby_llm_request_count' => '3' },
      'completionStats' => { 'successfulCount' => '4' },
      'outputInfo' => { 'gcsOutputDirectory' => output_uri } }
  end

  def descriptor(text, model_id: model, dimensions: 256)
    resolved = RubyLLM.models.find(model_id, provider: :vertexai)
    { custom_id: '0', model: model_id, text:,
      payload: provider.render_embedding(text, model: resolved, dimensions:) }
  end

  def output(key, vector, tokens = 2)
    { 'key' => key, 'predictions' => [{ 'embeddings' => {
      'values' => vector, 'statistics' => { 'token_count' => tokens }
    } }], 'status' => '' }
  end

  def stub_outputs(rows, metadata: job)
    allow(provider.connection).to receive(:get).and_return(Struct.new(:body).new(metadata))
    files = ["#{output_uri}/predictions_2.jsonl", "#{output_uri}/errors_1.jsonl", "#{output_uri}/manifest.txt"]
    allow(provider).to receive(:list_file_uris).with(output_uri).and_return(files)
    allow(provider).to receive(:download_file).with("#{output_uri}/predictions_2.jsonl")
                                              .and_return(rows.take(2).map(&:to_json).join("\n"))
    allow(provider).to receive(:download_file).with("#{output_uri}/errors_1.jsonl")
                                              .and_return(rows.drop(2).map(&:to_json).join("\n"))
  end

  it 'uploads legacy text instances with excluded correlation keys and job-wide dimensions' do
    uploaded = nil
    allow(provider).to receive(:upload_file) { |io, **| uploaded = io.string.lines.map { |line| JSON.parse(line) } }
    allow(provider.connection).to receive(:post).and_return(Struct.new(:body).new(job(state: 'JOB_STATE_PENDING')))
    request = descriptor(%w[Ruby Rails])
    request[:payload][:instances].first.merge!(task_type: 'RETRIEVAL_DOCUMENT', title: 'Ruby guide')

    result = protocol.create_batch([request])

    expect(uploaded).to eq([
                             { 'content' => 'Ruby', 'task_type' => 'RETRIEVAL_DOCUMENT', 'title' => 'Ruby guide',
                               'key' => 'rllm-0-0-2-a' },
                             { 'content' => 'Rails', 'key' => 'rllm-0-1-2-a' }
                           ])
    expect(result).to include(completed: false, request_count: 3)
    expect(provider.connection).to have_received(:post).with(
      'projects/test-project/locations/us-central1/batchPredictionJobs',
      include(model: "projects/test-project/locations/us-central1/publishers/google/models/#{model}",
              instanceConfig: { instanceType: 'object', keyField: 'key' },
              modelParameters: { outputDimensionality: 256 }, labels: { ruby_llm_request_count: '1' }),
      idempotent: false
    )
  end

  it 'renders Gemini Embedding 001 batch content and per-row task, title and dimensions' do
    request = descriptor('Ruby', model_id: 'gemini-embedding-001')
    request[:payload][:instances].first.merge!(task_type: 'RETRIEVAL_DOCUMENT', title: 'Guide')

    rows = protocol.send(:render_embedding_batch_rows, request)

    expect(rows).to eq([{ key: 'rllm-0-0-1-s', request: {
                         content: { parts: [{ text: 'Ruby' }] },
                         embed_content_config: { output_dimensionality: 256, task_type: 'RETRIEVAL_DOCUMENT',
                                                 title: 'Guide' }
                       } }])
  end

  it 'accepts different dimensions per Gemini embedding request without applying the legacy instance transform' do
    uploaded = nil
    allow(provider).to receive(:upload_file) { |io, **| uploaded = io.string.lines.map { |line| JSON.parse(line) } }
    response = Struct.new(:body).new(job(model_id: 'gemini-embedding-001'))
    allow(provider.connection).to receive(:post).and_return(response)
    requests = [descriptor('Ruby', model_id: 'gemini-embedding-001', dimensions: 128),
                descriptor('Rails', model_id: 'gemini-embedding-001', dimensions: 256).merge(custom_id: '1')]

    protocol.create_batch(requests)

    expect(uploaded.map { |row| row.dig('request', 'embed_content_config', 'output_dimensionality') }).to eq([128, 256])
    expect(provider.connection).to have_received(:post) do |_, payload, **|
      expect(payload).not_to have_key(:instanceConfig)
      expect(payload).not_to have_key(:modelParameters)
    end
  end

  it 'stages Gemini Embedding 2 arrays as independent content requests without changing synchronous input limits' do
    request = descriptor(%w[Ruby Rails], model_id: 'gemini-embedding-2')

    rows = protocol.send(:render_embedding_batch_rows, request)

    expect(rows.map { |row| row[:key] }).to eq(%w[rllm-0-0-2-a rllm-0-1-2-a])
    expect(rows.last[:request]).to eq(content: { parts: [{ text: 'Rails' }] },
                                      embed_content_config: { output_dimensionality: 256 })
    resolved = RubyLLM.models.find('gemini-embedding-2', provider: :vertexai)
    expect do
      provider.protocol_for(resolved, operation: :embed).new(provider)
              .render_embedding_payload(%w[Ruby Rails], model: resolved.id, dimensions: 256)
    end.to raise_error(ArgumentError, /one text/)
  end

  it 'rejects mixed dimensions on legacy jobs before uploading anything' do
    allow(provider).to receive(:upload_file)

    expect do
      protocol.create_batch([descriptor('Ruby'), descriptor('Rails', dimensions: 128)])
    end.to raise_error(ArgumentError, /same dimensions/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'rejects unsupported or mismatched requests before uploading anything' do
    allow(provider).to receive(:upload_file)
    request = descriptor('Ruby')

    expect { protocol.create_batch([request.merge(model: model_for(:vertexai))]) }
      .to raise_error(RubyLLM::Error, /not supported/)
    expect { protocol.create_batch([request.merge(text: [])]) }.to raise_error(ArgumentError, /nonempty/)
    expect do
      protocol.create_batch([request.merge(text: %w[Ruby Rails])])
    end.to raise_error(ArgumentError, /number of texts/)
    expect { provider.create_batch([request, { model:, payload: {} }]) }.to raise_error(RubyLLM::Error, /not both/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'rejects Gemini options it cannot translate instead of silently dropping them' do
    request = descriptor('Ruby', model_id: 'gemini-embedding-001')
    request[:payload][:parameters][:autoTruncate] = false
    allow(provider).to receive(:upload_file)

    expect { protocol.create_batch([request]) }.to raise_error(ArgumentError, /autoTruncate/)
    request[:payload][:extra] = true
    expect { protocol.create_batch([request]) }.to raise_error(ArgumentError, /extra/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'does not retry an uncertain non-idempotent submission' do
    RubyLLM.config.max_retries = 3
    allow(provider).to receive(:upload_file)
    stub_request(:post, %r{/batchPredictionJobs\z}).to_raise(Faraday::TimeoutError)

    expect { protocol.create_batch([descriptor('Ruby')]) }.to raise_error(Faraday::TimeoutError)
    expect(a_request(:post, %r{/batchPredictionJobs\z})).to have_been_made.once
  end

  it 'restores scalar, one-element array and multiple vectors across unordered shards' do
    stub_outputs([
                   output('rllm-2-1-2-a', [0.4, 0.5], 4),
                   output('rllm-0-0-1-s', [0.1, 0.2], 1),
                   output('rllm-2-0-2-a', [0.3, 0.4], 3),
                   output('rllm-1-0-1-a', [0.2, 0.3], 2)
                 ])

    results = protocol.batch_results(job_name).sort_by(&:first).map(&:last)

    expect(results.map(&:vectors)).to eq([[0.1, 0.2], [[0.2, 0.3]], [[0.3, 0.4], [0.4, 0.5]]])
    expect(results.map { |result| result.tokens.input }).to eq([1, 2, 7])
    expect(results.map(&:model)).to eq([model] * 3)
  end

  it 'parses the new Gemini result shape and preserves unknown usage' do
    rows = [
      { 'key' => 'rllm-0-0-1-s', 'response' => { 'embedding' => { 'values' => [0.1] }, 'tokenCount' => '3' } },
      { 'key' => 'rllm-1-0-1-a', 'response' => { 'embedding' => { 'values' => [0.2] } } }
    ]
    stub_outputs(rows, metadata: job(model_id: 'gemini-embedding-001'))

    results = protocol.batch_results(job_name).map(&:last)

    expect(results.map(&:vectors)).to eq([[0.1], [[0.2]]])
    expect(results.map { |result| result.tokens.input }).to eq([3, nil])
  end

  it 'fails malformed, duplicate and provider-error groups without inventing vectors' do
    rows = [output('rllm-0-0-2-a', [0.1]), output('rllm-0-0-2-a', [0.2]),
            { 'key' => 'rllm-1-0-1-s', 'error' => { 'code' => 3, 'message' => 'Invalid input' } },
            output('rllm-2-0-1-a', [])]
    stub_outputs(rows)

    expect(protocol.batch_results(job_name)).to eq([[0, nil, :failed], [1, nil, :failed], [2, nil, :failed]])
  end

  it 'rejects missing correlation keys instead of assigning a result to the wrong request' do
    stub_outputs([output('unrelated', [0.1])])

    expect { protocol.batch_results(job_name) }.to raise_error(RubyLLM::Error, /record key/)
  end

  it 'keeps missing group members pending until finalization and sizes reloaded jobs by logical requests' do
    stub_outputs([output('rllm-0-0-2-a', [0.1]), output('rllm-1-0-1-a', [0.2])],
                 metadata: job(state: 'JOB_STATE_RUNNING'))
    batch = RubyLLM::Batch.new(provider:, **provider.find_batch(job_name))

    expect(batch.batch_protocol).to eq('embedding_prediction')
    expect(batch.results.map { |result| result&.vectors }).to eq([nil, [[0.2]], nil])
    expect(batch.statuses).to eq([nil, :succeeded])

    allow(provider.connection).to receive(:get).and_return(Struct.new(:body).new(job))
    expect(batch.refresh.results.map { |result| result&.vectors }).to eq([nil, [[0.2]], nil])
    expect(batch.statuses).to eq(%i[failed succeeded failed])
  end

  it 'routes real staged embedding requests and delivers results through the public Batch API' do
    staged = ['Ruby', ['Rails'], %w[Python JavaScript]].map do |text|
      RubyLLM.embed_later(text, model:, provider: :vertexai, dimensions: 256)
    end
    chosen = staged.first.provider
    allow(chosen).to receive(:upload_file)
    allow(chosen.connection).to receive_messages(post: Struct.new(:body).new(job(state: 'JOB_STATE_PENDING')),
                                                 get: Struct.new(:body).new(job))

    batch = RubyLLM.batch(staged)

    expect(batch.batch_protocol).to eq('embedding_prediction')
    allow(chosen).to receive_messages(list_file_uris: ["#{output_uri}/out.jsonl"], download_file: [
      output('rllm-2-0-2-a', [0.3]), output('rllm-0-0-1-s', [0.1]),
      output('rllm-1-0-1-a', [0.2]), output('rllm-2-1-2-a', [0.4])
    ].map(&:to_json).join("\n"))
    expect(batch.refresh.results.map(&:vectors)).to eq([[0.1], [[0.2]], [[0.3], [0.4]]])
    expect(staged.map { |request| request.result.vectors }).to eq([[0.1], [[0.2]], [[0.3], [0.4]]])
    expect(batch.tokens.input).to eq(8)
  end
end
