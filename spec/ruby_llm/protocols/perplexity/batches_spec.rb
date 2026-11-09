# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Perplexity::Batches do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Perplexity.new(RubyLLM.config) }
  let(:protocol_class) { provider.protocols[:agent_responses] }
  let(:protocol) { protocol_class.new(provider) }
  let(:connection) { provider.connection }

  def response(body)
    instance_double(Faraday::Response, body:)
  end

  def result(custom_id, http_response, error: nil)
    { custom_id:, response: http_response, error: }
  end

  def completed_body(text)
    { id: 'resp_1', object: 'response', status: 'completed', model: 'openai/gpt-5-nano',
      output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: }] }],
      usage: { input_tokens: 3, output_tokens: 1, total_tokens: 4 } }
  end

  it 'makes the Agent API the batch protocol' do
    expect(provider.batches?).to be(true)
    expect(protocol_class).to be < described_class
  end

  it 'uploads Agent API requests as JSONL and creates the batch against /v1/responses' do
    upload = nil
    allow(provider).to receive(:upload_file) do |file, **options|
      upload = [file.read, options]
      instance_double(RubyLLM::UploadedFile, id: 'file_1')
    end
    headers = {}
    allow(connection).to receive(:post) do |_url, _payload, &block|
      block&.call(instance_double(Faraday::Request, headers:))
      response('id' => 'batch_1', 'status' => 'validating', 'request_counts' => { 'total' => 1 })
    end

    batch = protocol.create_batch([{ custom_id: '0', model: 'openai/gpt-5-nano',
                                     payload: { model: 'openai/gpt-5-nano', input: 'Hi', stream: true } }])

    expect(JSON.parse(upload.first)).to eq(
      'custom_id' => '0', 'method' => 'POST', 'url' => '/v1/responses',
      'body' => { 'model' => 'openai/gpt-5-nano', 'input' => 'Hi' }
    )
    expect(upload.last).to include(purpose: 'batch')
    expect(connection).to have_received(:post).with(
      'v1/batches', { input_file_id: 'file_1', endpoint: '/v1/responses', completion_window: '24h' }
    )
    expect(headers['Idempotency-Key']).to match(/\A\h{8}-/)
    expect(batch).to include(id: 'batch_1', raw_status: 'validating', completed: false, request_count: 1)
  end

  it 'refuses mixed models and payloads that are not Agent API requests before uploading' do
    allow(provider).to receive(:upload_file)
    mixed = [{ custom_id: '0', model: 'a', payload: { input: 'Hi' } },
             { custom_id: '1', model: 'b', payload: { input: 'Hi' } }]
    chat_payload = [{ custom_id: '0', model: 'a', payload: { messages: [] } }]

    expect { protocol.create_batch(mixed) }.to raise_error(RubyLLM::Error, /one model per submission/)
    expect { protocol.create_batch(chat_payload) }.to raise_error(RubyLLM::Error, /require responses payloads/)
    expect(provider).not_to have_received(:upload_file)
  end

  it 'reads a batch and cancels it under /v1/batches' do
    allow(connection).to receive(:get).with('v1/batches/batch_1')
                                      .and_return(response('id' => 'batch_1', 'status' => 'expired'))
    allow(connection).to receive(:post).with('v1/batches/batch_1/cancel', {})
                                       .and_return(response('id' => 'batch_1', 'status' => 'cancelling'))

    expect(protocol.find_batch('batch_1')).to include(completed: true, raw_status: 'expired')
    expect(protocol.cancel_batch('batch_1')).to include(completed: false, raw_status: 'cancelling')
  end

  it 'collects answers, failed responses, rejected requests, and expired requests from both files' do
    output = [result('1', { status_code: 200, body: completed_body('Jupiter') }),
              result('2', { status_code: 200, body: completed_body('x').merge(status: 'failed') })]
    errors = [result('0', { status_code: 400, body: { error: { message: 'too long' } } }),
              result('3', nil, error: { code: 'batch_expired', message: 'Expired before it ran.' })]
    allow(connection).to receive(:get).with('v1/batches/batch_1').and_return(
      response('id' => 'batch_1', 'status' => 'completed', 'output_file_id' => 'file_out',
               'error_file_id' => 'file_err')
    )
    allow(provider).to receive(:download_file).with('file_out').and_return(output.map(&:to_json).join("\n"))
    allow(provider).to receive(:download_file).with('file_err').and_return(errors.map(&:to_json).join("\n"))

    results = protocol.batch_results('batch_1').sort_by(&:first)

    expect(results[1][1]).to have_attributes(content: 'Jupiter')
    expect(results.values_at(0, 2, 3).map { |slot| slot[1..2] }).to all(eq([nil, :failed]))
  end
end
