# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Cohere::Batches do
  let(:context) { RubyLLM.context { |config| config.cohere_api_key = 'test' } }
  let(:model) { model_for(:cohere) }
  let(:embedding_model) { model_for(:cohere, :embedding) }
  let(:datasets) { instance_double(RubyLLM::Protocols::Cohere::Datasets) }
  let(:created_datasets) { [] }

  def protocol
    RubyLLM::Protocols::Cohere.new(RubyLLM::Providers::Cohere.new(context.config))
  end

  def batch_data(model:, count:, status: 'BATCH_STATUS_COMPLETED')
    { id: 'batch_ruby', model:, status:, input_dataset_id: 'dataset_input', output_dataset_id: 'dataset_output',
      num_records: count, num_successful_records: count, num_failed_records: 0 }
  end

  def stub_datasets(rows = [])
    file = RubyLLM::UploadedFile.new(id: 'dataset_input', provider: 'cohere', status: 'validated')
    allow(RubyLLM::Protocols::Cohere::Datasets).to receive(:new).and_return(datasets)
    allow(datasets).to receive_messages(upload: file, wait_for_validation: file, records: rows)
  end

  def embedding_row(id, vectors, tokens)
    body = { 'embeddings' => { 'float' => vectors }, 'meta' => { 'billed_units' => { 'input_tokens' => tokens } } }
    { 'custom_id' => id, 'error' => '', 'body' => body }
  end

  before do |example|
    next unless example.metadata[:live]

    RubyLLM.config.max_retries = 2
    RubyLLM.config.request_timeout = 45
    allow(RubyLLM::Protocols::Cohere::Datasets).to receive(:new).and_wrap_original do |constructor, *args|
      constructor.call(*args).tap do |instance|
        allow(instance).to receive(:upload).and_wrap_original do |upload, *upload_args, **options|
          upload.call(*upload_args, **options).tap { |file| created_datasets << file.id }
        end
      end
    end
  end

  it 'preserves scalar and array embeddings across a fresh Batch.find and out-of-order output' do
    rows = [embedding_row('2:array', [[5, 6], [7, 8]], 4), embedding_row('0', [[1, 2]], 2),
            embedding_row('1:array', [[3, 4]], 3)]
    stub_datasets(rows)
    response = batch_data(model: embedding_model, count: 3)
    stub_request(:post, 'https://api.cohere.com/v2/batches').to_return_json(body: { batch: response })
    stub_request(:get, 'https://api.cohere.com/v2/batches/batch_ruby').to_return_json(body: { batch: response })
    requests = ['one', ['two'], %w[three four]].map do |text|
      context.embed_later(text, model: embedding_model, provider: :cohere)
    end

    batch = RubyLLM.batch(requests)
    expect(batch.results.map(&:vectors)).to eq([[1, 2], [[3, 4]], [[5, 6], [7, 8]]])
    expect(requests.map(&:result)).to eq(batch.results)
    restored = RubyLLM::Batch.find(batch.id, provider: :cohere, context:)
    expect(restored.results.map(&:vectors)).to eq(batch.results.map(&:vectors))
    expect(restored.tokens.input).to eq(9)
    expect(restored.statuses).to eq(%i[succeeded succeeded succeeded])
    expect(datasets).to have_received(:upload) do |input, **options|
      lines = input.string.lines.map { |line| JSON.parse(line) }
      expect(options[:purpose]).to eq('batch-embed-v2-input')
      expect(lines.map { |line| line['custom_id'] }).to eq(['0', '1:array', '2:array'])
      expect(lines.first['body']).to include('texts' => ['one'])
    end
  end

  it 'collects typed messages and individual failures with provider usage and returned tool calls' do
    body = {
      'finish_reason' => 'TOOL_CALL',
      'message' => { 'role' => 'assistant', 'content' => [{ 'type' => 'text', 'text' => 'Checking.' }],
                     'tool_calls' => [{ 'id' => 'call_weather', 'type' => 'function',
                                        'function' => { 'name' => 'weather', 'arguments' => '{"city":"Berlin"}' } }] },
      'usage' => { 'tokens' => { 'input_tokens' => 12, 'output_tokens' => 7 } }
    }
    stub_datasets([{ 'custom_id' => '1', 'error' => 'Invalid request', 'body' => nil },
                   { 'custom_id' => '0', 'error' => '', 'body' => body }])
    response = batch_data(model:, count: 2).merge(num_successful_records: 1, num_failed_records: 1)
    stub_request(:get, 'https://api.cohere.com/v2/batches/batch_ruby').to_return_json(body: { batch: response })

    batch = RubyLLM::Batch.find('batch_ruby', provider: :cohere, context:)
    message = batch.results.first

    expect(message).to have_attributes(content: 'Checking.', model:, finish_reason: :tool_calls)
    expect(message.tool_calls.fetch('call_weather')).to have_attributes(name: 'weather',
                                                                        arguments: { 'city' => 'Berlin' })
    expect(message.tokens).to have_attributes(input: 12, output: 7)
    expect(batch.results.last).to be_nil
    expect(batch.statuses).to eq(%i[succeeded failed])
  end

  it 'normalizes batch-only tool, image and thinking fields without changing a chat render' do
    image = { type: 'image_url', image_url: { url: 'https://example.test/ruby.png' } }
    body = {
      model:, messages: [{ role: 'user', content: [image] },
                         { role: 'tool', content: 'Sunny', tool_call_id: 'call_weather' }],
      tools: [{ type: 'function', function: { name: 'weather', parameters: { type: 'object' } } }],
      thinking: { type: 'enabled', token_budget: 512 }, stream: false
    }
    request = { custom_id: '0', model:, payload: body }
    rendered = protocol.render_batch_request(request, type: 'batch-chat-v2-input')[:body]

    expect(rendered).to include('reasoning' => true, 'thinking_budget' => 512)
    expect(rendered.dig('messages', 0, 'content', 0, 'image_url')).to eq('https://example.test/ruby.png')
    expect(rendered.dig('messages', 1, 'content')).to eq([{ 'type' => 'text', 'text' => 'Sunny' }])
    expect(rendered.dig('tools', 0, 'function', 'parameters')).to eq('{"type":"object"}')
    expect(body.dig(:tools, 0, :function, :parameters)).to eq(type: 'object')
    expect(body).to include(thinking: { type: 'enabled', token_budget: 512 }, stream: false)
  end

  it 'rejects options absent from the batch schema before creating any dataset' do
    request = { custom_id: '0', model:, payload: { messages: [], response_format: { type: 'json_object' } } }
    expect { protocol.create_batch([request]) }.to raise_error(ArgumentError, /response_format/)
    expect(a_request(:post, /datasets/)).not_to have_been_made
    embedding = context.embed_later('Ruby', model: embedding_model, provider: :cohere, dimensions: 256)
    expect { RubyLLM.batch(embedding) }.to raise_error(ArgumentError, /omit dimensions/)
  end

  it 'rejects duplicate result IDs and retains cancellation status' do
    stub_datasets([embedding_row('0', [[1, 2]], 2), embedding_row('0', [[3, 4]], 2)])
    response = batch_data(model: embedding_model, count: 2)
    stub_request(:get, 'https://api.cohere.com/v2/batches/batch_ruby')
      .to_return_json(body: { batch: response })
    expect { protocol.batch_results('batch_ruby') }.to raise_error(RubyLLM::Error, /duplicate batch request IDs/)
    stub_request(:post, 'https://api.cohere.com/v2/batches/batch_ruby/cancel').to_return_json(body: {})
    stub_request(:get, 'https://api.cohere.com/v2/batches/batch_ruby')
      .to_return_json(body: { batch: response.merge(status: 'BATCH_STATUS_CANCELED') })
    batch = RubyLLM::Batch.find('batch_ruby', provider: :cohere, context:)
    expect(batch.cancel).to be_cancelled
  end

  it 'does not fetch an output dataset while a batch reports an empty output ID' do
    response = batch_data(model:, count: 1, status: 'BATCH_STATUS_QUEUED').merge(output_dataset_id: '')
    stub_request(:get, 'https://api.cohere.com/v2/batches/batch_ruby').to_return_json(body: { batch: response })

    expect(protocol.batch_results('batch_ruby')).to eq([])
    expect(a_request(:get, 'https://api.cohere.com/v1/datasets/')).not_to have_been_made
  end

  it 'does not repeat a batch submission after an uncertain server response' do
    context.config.max_retries = 2
    stub_datasets
    request = stub_request(:post, 'https://api.cohere.com/v2/batches')
              .to_return(status: 502, body: '{"message":"Upstream unavailable"}',
                         headers: { 'Content-Type' => 'application/json' })
    chat = context.chat(model:, provider: :cohere).ask_later('Reply with Ruby only.')

    expect { RubyLLM.batch(chat) }.to raise_error(RubyLLM::Error, /Upstream unavailable/)
    expect(request).to have_been_requested.once
  end

  def wait_for_cohere_batch(batch)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 45
    until batch.refresh.complete?
      raise "Cohere batch is still pending: #{batch.id}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 2
    end
    batch
  end

  it 'filters signed dataset URLs through the registered recording hooks' do
    url = 'https://storage.googleapis.com/cohere-production-user-datasets/result.avro?' \
          'X-Goog-Credential=private-account&X-Goog-Signature=private-signature&X-Goog-Expires=3600'
    %W[https://api.cohere.com/v1/datasets/output #{url}].each do |uri|
      interaction = VCR::HTTPInteraction.new(
        VCR::Request.new(:get, uri, '', {}),
        VCR::Response.new(VCR::ResponseStatus.new(200, 'OK'), {}, JSON.generate(url:), '1.1')
      )

      VCR.configuration.invoke_hook(:before_record, interaction.hook_aware, VCR.current_cassette)

      expect(interaction.request.uri).not_to include('private-')
      expect(JSON.parse(interaction.response.body).fetch('url')).to eq(
        url.sub('private-account', 'FILTERED_CREDENTIAL').sub('private-signature', 'FILTERED_SIGNATURE')
      )
    end
  end

  def clean_up_cohere_batch(batch)
    connection = RubyLLM::Providers::Cohere.new(RubyLLM.config).connection
    data = cleanup_batch_data(batch, connection)
    ids = created_datasets + [data['input_dataset_id'], data['output_dataset_id']]
    ids.compact.reject(&:empty?).uniq.each do |id|
      connection.delete("v1/datasets/#{id}")
    rescue RubyLLM::Error => e
      raise unless e.response&.status == 404
    end
  end

  def cleanup_batch_data(batch, connection)
    return {} unless batch

    data = connection.get("v2/batches/#{batch.id}").body.fetch('batch')
    batch.cancel unless %w[BATCH_STATUS_COMPLETED BATCH_STATUS_FAILED BATCH_STATUS_CANCELED].include?(data['status'])
    data
  rescue RubyLLM::ServiceUnavailableError
    warn "Cohere did not return cleanup metadata for test batch #{batch.id}"
    {}
  end

  it 'collects completed Cohere chat responses with returned IDs and token usage', :live do
    chats = %w[Ruby Rails].map do |word|
      RubyLLM.chat(model:, provider: :cohere).with_max_output_tokens(16).ask_later("Reply with #{word} only.")
    end
    batch = RubyLLM.batch(chats)
    wait_for_cohere_batch(batch)
    restored = RubyLLM::Batch.find(batch.id, provider: :cohere)
    results = restored.results

    expect(restored).to be_succeeded
    expect(results.map(&:content)).to match([/\bruby\b/i, /\brails\b/i])
    expect(results.map(&:model)).to eq([model, model])
    expect(results.map { |message| message.raw['id'] }).to all(be_a(String))
    expect(restored.tokens.input).to be > 0
    expect(restored.tokens.output).to be > 0
    expect(restored.statuses).to eq(%i[succeeded succeeded])
  rescue RubyLLM::ServiceUnavailableError => e
    skip "Cohere batch service unavailable (HTTP #{e.response&.status}); batch ID: #{batch&.id || 'not returned'}"
  ensure
    clean_up_cohere_batch(batch)
  end

  it 'collects completed Cohere embedding batches with scalar and array results', :live do
    requests = ['Ruby makes AI useful.', ['Rails makes applications enjoyable.'], %w[Ruby Rails]].map do |text|
      RubyLLM.embed_later(text, model: embedding_model, provider: :cohere)
    end
    batch = RubyLLM.batch(requests)
    wait_for_cohere_batch(batch)
    restored = RubyLLM::Batch.find(batch.id, provider: :cohere)
    results = restored.results

    expect(restored).to be_succeeded
    expect(results[0].vectors.size).to eq(1536)
    expect(results[1].vectors.map(&:size)).to eq([1536])
    expect(results[2].vectors.map(&:size)).to eq([1536, 1536])
    expect(results.map(&:model)).to eq([embedding_model] * 3)
    expect(results.map { |embedding| embedding.tokens.input }).to all(be > 0)
    expect(restored.statuses).to eq(%i[succeeded succeeded succeeded])
  rescue RubyLLM::ServiceUnavailableError => e
    skip "Cohere batch service unavailable (HTTP #{e.response&.status}); batch ID: #{batch&.id || 'not returned'}"
  ensure
    clean_up_cohere_batch(batch)
  end
end
