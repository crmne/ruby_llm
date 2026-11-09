# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Perplexity::Files do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Perplexity.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider) }
  let(:data) { { 'id' => 'file_123', 'filename' => 'numbers.csv', 'bytes' => 9, 'created_at' => 100 } }

  it 'binds a generated file to its response and preserves native metadata' do
    file = protocol.parse_response_file('resp_123', data)
    expect(file).to have_attributes(id: 'resp_123/files/file_123', filename: 'numbers.csv', byte_size: 9,
                                    provider: 'perplexity', created_at: Time.at(100), downloadable: true)
    expect(file.metadata).to eq(data.merge('response_id' => 'resp_123'))
  end

  it 'finds and downloads only the bound generated file through the provider connection' do
    allow(provider.connection).to receive(:get).with('v1/agent/resp_123/files')
                                               .and_return(instance_double(Faraday::Response,
                                                                           body: { 'data' => [data] }))
    allow(provider.connection).to receive(:get).with('v1/agent/resp_123/files/file_123/content', raw: true)
                                               .and_return(instance_double(Faraday::Response, body: "value\n91\n"))
    expect(protocol.find('resp_123/files/file_123').filename).to eq('numbers.csv')
    expect(protocol.download('resp_123/files/file_123')).to eq("value\n91\n")
  end

  it 'rejects arbitrary URLs and traversal without sending credentials' do
    allow(provider.connection).to receive(:get)
    ['https://example.com/file', 'resp/../../files/file', 'resp/files/file?token=123', 'a/b'].each do |id|
      expect { protocol.download(id) }.to raise_error(ArgumentError, /must be a file id or response_id/)
    end
    expect(provider.connection).not_to have_received(:get)
  end

  it 'reports a generated file the response does not list' do
    allow(provider.connection).to receive(:get).with('v1/agent/resp_123/files')
                                               .and_return(instance_double(Faraday::Response, body: { 'data' => [] }))

    expect { protocol.find('resp_123/files/file_123') }.to raise_error(RubyLLM::Error, /was not found/)
  end

  it 'refuses a generated file whose id would leave its response' do
    expect { protocol.parse_response_file('resp_123', data.merge('id' => '../secret')) }
      .to raise_error(ArgumentError, /must be a file id/)
  end

  it 'reads the MIME type from either field a generated file reports' do
    file = protocol.parse_response_file('resp_123', data.merge('mime_type' => 'text/csv'))

    expect(file.mime_type).to eq('text/csv')
  end

  it 'uploads batch input with its purpose to the Files API' do
    response = instance_double(Faraday::Response, body: { 'id' => 'file_456', 'filename' => 'batch.jsonl', 'bytes' => 7,
                                                          'created_at' => 100, 'expires_at' => 200,
                                                          'purpose' => 'batch' })
    allow(provider.connection).to receive(:post).and_return(response)

    file = protocol.upload(StringIO.new('{"a":1}'), filename: 'batch.jsonl', purpose: 'batch')

    expect(provider.connection).to have_received(:post)
      .with('v1/files', hash_including(purpose: 'batch', file: be_a(Faraday::Multipart::FilePart)), idempotent: false)
    expect(file).to have_attributes(id: 'file_456', purpose: 'batch', expires_at: Time.at(200),
                                    mime_type: 'application/jsonl')
  end

  it 'finds and downloads a stored batch file by its own id' do
    allow(provider.connection).to receive(:get).with('v1/files/file_456')
                                               .and_return(instance_double(Faraday::Response, body: data))
    allow(provider.connection).to receive(:get).with('v1/files/file_456/content', raw: true)
                                               .and_return(instance_double(Faraday::Response, body: "{}\n"))

    expect(protocol.find('file_456').id).to eq('file_123')
    expect(protocol.download('file_456')).to eq("{}\n")
  end
end
