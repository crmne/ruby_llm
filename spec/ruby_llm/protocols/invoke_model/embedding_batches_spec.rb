# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::InvokeModel::EmbeddingBatches do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:bedrock, :embedding) }
  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }
  let(:protocol) { provider.embedding_batch_protocol(model).new(provider) }
  let(:job_id) { 'arn:aws:bedrock:us-west-2:123456789012:model-invocation-job/fixture' }
  let(:live_resources) { {} }

  def control
    'https://bedrock.us-west-2.amazonaws.com'
  end

  def requests
    ['Ruby', ['Rails'], %w[Python JavaScript]].map do |text|
      RubyLLM.embed_later(text, model:, provider: :bedrock, dimensions: 256)
    end
  end

  def job(status = 'Completed')
    { 'jobArn' => job_id, 'status' => status, 'modelId' => model, 'modelInvocationType' => 'InvokeModel',
      'jobName' => 'ruby-llm-embed-3-0123456789abcdef',
      'outputDataConfig' => { 's3OutputDataConfig' => { 's3Uri' => 's3://ruby-llm-batches/test/output' } } }
  end

  def output(id, vector, tokens = 2)
    { recordId: id, modelOutput: { embedding: vector, inputTextTokenCount: tokens } }.to_json
  end

  def stub_job(records)
    allow(provider).to receive_messages(control_api_base: control,
                                        signed_get: Struct.new(:body).new(job),
                                        list_file_uris: ['s3://ruby-llm-batches/test/output/shard.jsonl.out'],
                                        download_file: records.join("\n"))
  end

  def restore_recorded_batch_resources
    return if VCR.current_cassette.recording?

    request = VCR.current_cassette.http_interactions.interactions
                 .find { |interaction| interaction.request.uri.end_with?('/model-invocation-job') }&.request
    return unless request

    payload = JSON.parse(request.body)
    input = payload.dig('inputDataConfig', 's3InputDataConfig', 's3Uri')
    prefix, directory = input.match(%r{\A(.+)/ruby_llm_batches/([0-9a-f]{16})/input\.jsonl\z}).captures
    RubyLLM.config.bedrock_batch_s3_uri = prefix
    RubyLLM.config.bedrock_batch_role_arn = payload.fetch('roleArn')
    allow(SecureRandom).to receive(:hex).and_call_original
    allow(SecureRandom).to receive(:hex).with(8).and_return(directory)
  end

  def submit_live_embedding_batch
    %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY BEDROCK_BATCH_S3_URI BEDROCK_BATCH_ROLE_ARN].each do |key|
      skip_without_cassette_or_key(key)
    end
    restore_recorded_batch_resources
    inputs = ['Ruby', ['Rails'], Array.new(98) { |index| "Ruby language #{index}" }]
    staged = inputs.map { |text| RubyLLM.embed_later(text, model:, provider: :bedrock, dimensions: 256) }
    live_resources[:provider] = staged.first.provider
    allow(live_resources[:provider]).to receive(:upload_file).and_wrap_original do |method, *args, **options|
      live_resources[:input_uri] = options.fetch(:uri)
      method.call(*args, **options)
    end
    RubyLLM.batch(staged)
  end

  def cleanup_live_embedding_batch(batch)
    return unless batch

    batch.cancel unless batch.complete?
    return unless batch.complete? && live_resources[:input_uri]

    prefix = live_resources[:input_uri].delete_suffix('input.jsonl')
    files = RubyLLM::Protocols::Bedrock::Files.new(live_resources[:provider])
    client = files.send(:s3_client)
    files.list_uris(prefix).each do |file|
      raise "Unexpected batch fixture output: #{file}" unless file.start_with?(prefix)

      uri = URI(file)
      client.delete_object(bucket: uri.host, key: uri.path.delete_prefix('/'))
    end
  end

  def wait_for_live_embedding_batch(batch)
    36.times do
      return batch if batch.refresh.complete?

      sleep 5 if VCR.current_cassette.recording?
    end
    skip 'Bedrock embedding batch did not finish within 180 seconds; completed results remain unverified'
  end

  it 'stages real Titan request bodies and submits InvokeModel records with scalar and array identity' do
    staged = requests
    chosen = staged.first.provider
    uploaded = nil
    allow(chosen).to receive(:upload_file) { |io, **| uploaded = io.string.lines.map { |line| JSON.parse(line) } }
    allow(chosen).to receive_messages(signed_post: Struct.new(:body).new({ 'jobArn' => job_id }),
                                      signed_get: Struct.new(:body).new(job('Submitted')))

    batch = RubyLLM.batch(staged)

    expect(batch.status).to eq(:pending)
    expect(batch.batch_protocol).to eq('titan_text_embeddings')
    expect(uploaded.map { |record| record['recordId'] })
      .to eq(%w[rllm-0-0-1-s rllm-1-0-1-a rllm-2-0-2-a rllm-2-1-2-a])
    expect(uploaded.map { |record| record.dig('modelInput', 'inputText') }).to eq(%w[Ruby Rails Python JavaScript])
    expect(uploaded.map { |record| record['modelInput'] }).to all(include('dimensions' => 256, 'normalize' => true))
    expect(chosen).to have_received(:signed_post).with(control, '/model-invocation-job',
                                                       include(modelInvocationType: 'InvokeModel', modelId: model,
                                                               clientRequestToken: match(/\A[0-9a-f]{64}\z/),
                                                               jobName: match(/\Aruby-llm-embed-3-/)))
  end

  it 'collects shuffled shards into typed logical embeddings and preserves missing usage' do
    stub_job([output('rllm-2-1-2-a', [0.3, 0.4], nil), output('rllm-0-0-1-s', [0.1, 0.2]),
              output('rllm-1-0-1-a', [0.5, 0.6]), output('rllm-2-0-2-a', [0.7, 0.8])])
    result = protocol.batch_results(job_id).to_h

    expect(result[0]).to be_a(RubyLLM::Embedding)
    expect(result[0].vectors).to eq([0.1, 0.2])
    expect(result[1].vectors).to eq([[0.5, 0.6]])
    expect(result[2].vectors).to eq([[0.7, 0.8], [0.3, 0.4]])
    expect(result[2].tokens.input).to be_nil
    expect(result[0].tokens.input).to eq(2)
  end

  it 'restores the InvokeModel parser and logical slot count through public Batch.find' do
    records = [output('rllm-0-0-1-s', [0.1, 0.2]), output('rllm-1-0-1-a', [0.3, 0.4])]
    stub_job(records)
    allow(RubyLLM::Providers::Bedrock).to receive(:new).and_return(provider)

    batch = RubyLLM::Batch.find(job_id, provider: :bedrock)
    result = batch.results

    expect(batch.batch_protocol).to eq('titan_text_embeddings')
    expect(result.size).to eq(3)
    expect(result[0].vectors).to eq([0.1, 0.2])
    expect(result[1].vectors).to eq([[0.3, 0.4]])
    expect(result[2]).to be_nil
    expect(batch.statuses).to eq(%i[succeeded succeeded failed])
    expect(result[0].model).to eq(model)
  end

  it 'fails a logical array on provider errors and rejects duplicate output positions' do
    records = [output('rllm-0-0-2-a', [0.1]),
               { recordId: 'rllm-0-1-2-a', error: { message: 'Invalid input' } }.to_json,
               output('rllm-1-0-1-s', [0.2]), output('rllm-1-0-1-s', [0.3])]
    stub_job(records)
    expect(protocol.batch_results(job_id)).to eq([[0, nil, :failed], [1, nil, :failed]])
  end

  it 'does not deliver incomplete arrays and rejects malformed indices and empty vectors' do
    stub_job([output('rllm-0-0-2-a', [0.1])])
    expect(protocol.batch_results(job_id)).to eq([])
    stub_job([output('rllm-0-1-1-s', [0.1])])
    expect(protocol.batch_results(job_id)).to eq([[0, nil, :failed]])
    stub_job([output('rllm-0-0-1-s', [])])
    expect(protocol.batch_results(job_id)).to eq([[0, nil, :failed]])
    stub_job([output('unknown-id', [0.1])])
    expect { protocol.batch_results(job_id) }.to raise_error(RubyLLM::Error, /record ID/)
  end

  it 'rejects scalar records describing multiple vectors and nonnumeric embedding values' do
    stub_job([output('rllm-0-0-2-s', [0.1]), output('rllm-0-1-2-s', [0.2]),
              output('rllm-1-0-1-s', ['invalid']), output('rllm-2-0-1-a', [nil])])

    expect(protocol.batch_results(job_id)).to eq([[0, nil, :failed], [1, nil, :failed], [2, nil, :failed]])
  end

  it 'keeps collection idempotent while filling original embedding requests and their ledger once' do
    staged = requests
    chosen = staged.first.provider
    allow(chosen).to receive_messages(
      batch_results: [[0, RubyLLM::Embedding.new(vectors: [0.1], model:, input_tokens: 2)],
                      [1, RubyLLM::Embedding.new(vectors: [[0.2]], model:, input_tokens: 3)],
                      [2, RubyLLM::Embedding.new(vectors: [[0.3], [0.4]], model:, input_tokens: 4)]]
    )
    batch = RubyLLM::Batch.new(provider: chosen, requests: staged, id: job_id,
                               raw_status: 'Completed', completed: true, batch_protocol: :titan_text_embeddings)
    original = batch.results
    expect(staged.map(&:result)).to eq(original)
    batch.results
    expect(staged.map(&:result)).to eq(original)
    expect(original.map { |result| result.ruby_llm_usage_entries.size }).to eq([1, 1, 1])
  end

  it 'uses the Titan multimodal text request envelope without passing an unsupported model keyword' do
    multimodal_model = model_for(:bedrock, :titan_multimodal_embedding)
    request = RubyLLM.embed_later('Ruby', model: multimodal_model, provider: :bedrock, dimensions: 256)
    payload = request.render
    expect(payload).to eq(inputText: 'Ruby', embeddingConfig: { outputEmbeddingLength: 256 })
    expect(provider.embedding_batch_protocol(multimodal_model)).not_to be_nil
  end

  it 'requires caller-selected resources and valid inputs before uploading anything' do
    staged = requests
    lines = staged.each_with_index.map do |request, index|
      { custom_id: index.to_s, model:,
        payload: request.render, text: request.text }
    end
    allow(provider).to receive(:upload_file)
    RubyLLM.config.bedrock_batch_role_arn = nil
    expect { protocol.create_batch(lines) }.to raise_error(RubyLLM::ConfigurationError, /role_arn/)
    RubyLLM.config.bedrock_batch_role_arn = 'arn:aws:iam::123456789012:role/BedrockBatch'
    RubyLLM.config.bedrock_batch_s3_uri = nil
    expect { protocol.create_batch(lines) }.to raise_error(RubyLLM::ConfigurationError, /s3_uri/)
    expect { protocol.create_batch([lines.first.merge(text: [])]) }.to raise_error(ArgumentError, /nonempty/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'rejects unsupported embedding models before uploading and preserves cancellation after reloading' do
    allow(provider).to receive(:upload_file)
    unsupported = { custom_id: '0', model: model_for(:bedrock, :multimodal_embedding),
                    text: 'Ruby', payload: { texts: ['Ruby'] } }
    expect { provider.create_batch([unsupported]) }.to raise_error(RubyLLM::Error, /supported Titan/)
    expect(provider).not_to have_received(:upload_file)

    allow(provider).to receive_messages(signed_post: Struct.new(:body).new({}),
                                        signed_get: Struct.new(:body).new(job('Stopped')))
    cancelled = provider.cancel_batch(job_id)
    expect(cancelled).to include(raw_status: 'Stopped', request_count: 3, completed: true)
    expect(cancelled[:batch_protocol]).to eq(provider.embedding_batch_protocol(model))
    expect(provider).to have_received(:signed_post).with(control, %r{/stop\z}, {})
  end

  it 'submits, reloads and cancels an embedding batch using explicitly configured S3 resources', :live do
    batch = submit_live_embedding_batch

    expect(batch.id).not_to be_empty
    expect(batch.requests.size).to eq(3)
    loaded = RubyLLM::Batch.find(batch.id, provider: :bedrock)
    expect(loaded.batch_protocol).to eq('titan_text_embeddings')
    expect(loaded.id).to eq(batch.id)
    expect(loaded.status).to eq(:pending)
  ensure
    cleanup_live_embedding_batch(batch)
  end

  it 'collects completed embedding vectors with original scalar and array shapes from S3', :live do
    batch = submit_live_embedding_batch
    wait_for_live_embedding_batch(batch)
    expect(batch).to be_succeeded
    results = batch.results

    expect(results).to all(be_a(RubyLLM::Embedding))
    expect(results.map { |result| result.vectors.size }).to eq([256, 1, 98])
    expect([results[0].vectors, *results[1].vectors, *results[2].vectors]).to all(all(be_a(Float)))
    expect(results.map { |result| result.tokens.input }).to all(be_positive)
    expect(batch.requests.map(&:result)).to eq(results)
    expect(batch.statuses).to eq(%i[succeeded succeeded succeeded])
    loaded = RubyLLM::Batch.find(batch.id, provider: :bedrock)
    expect(loaded.results.map(&:vectors)).to eq(results.map(&:vectors))
  ensure
    cleanup_live_embedding_batch(batch)
  end
end
