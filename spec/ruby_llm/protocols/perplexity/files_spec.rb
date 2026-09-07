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
    allow(provider.connection).to receive(:get).with('v1/agent/resp_123/files/file_123/content')
                                               .and_return(instance_double(Faraday::Response, body: "value\n91\n"))
    expect(protocol.find('resp_123/files/file_123').filename).to eq('numbers.csv')
    expect(protocol.download('resp_123/files/file_123')).to eq("value\n91\n")
  end

  it 'rejects unscoped IDs arbitrary URLs and traversal without sending credentials' do
    allow(provider.connection).to receive(:get)
    ['file_123', 'https://example.com/file', 'resp/../../files/file', 'resp/files/file?token=123'].each do |id|
      expect { protocol.download(id) }.to raise_error(ArgumentError, /must include their response/)
    end
    expect { protocol.upload('spec/fixtures/ruby.png') }.to raise_error(RubyLLM::Error, /only supports downloading/)
    expect(provider.connection).not_to have_received(:get)
  end
end
