# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Batches do
  let(:config) do
    RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:batch_calls) { { posts: [], uploads: [] } }
  let(:protocol) do
    RubyLLM::Providers::OpenAI.batch_protocols.fetch(:responses).allocate.tap do |instance|
      instance.instance_variable_set(:@provider, provider)
      instance.instance_variable_set(:@connection, connection)
    end
  end

  before do
    allow(provider).to receive(:upload_file) do |io, **options|
      batch_calls[:uploads] << [io.string, options]
      instance_double(RubyLLM::UploadedFile, id: 'file_123')
    end
    allow(connection).to receive(:post) do |url, body|
      batch_calls[:posts] << [url, body]
      Struct.new(:body).new({ 'id' => 'batch_123', 'status' => 'validating' })
    end
  end

  describe '#create_batch' do
    it 'uploads JSONL through the provider files API and creates a Responses batch' do
      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'gpt-5-nano',
                                params: { model: 'gpt-5-nano', input: 'hi', stream: false }
                              }
                            ])

      expect(batch_calls[:uploads].last.last).to include(purpose: 'batch', filename: 'ruby_llm_batch.jsonl')
      expect(batch_calls[:posts].last).to eq([
                                               'batches',
                                               {
                                                 input_file_id: 'file_123',
                                                 endpoint: '/v1/responses',
                                                 completion_window: '24h'
                                               }
                                             ])
      expect(uploaded_line).to include('url' => '/v1/responses')
      expect(uploaded_line.fetch('body')).not_to have_key('stream')
    end

    it 'rejects mixed-model batches' do
      requests = [
        { custom_id: '0', model: 'gpt-5-nano', params: { model: 'gpt-5-nano', input: 'hi' } },
        { custom_id: '1', model: 'gpt-5-mini', params: { model: 'gpt-5-mini', input: 'hi' } }
      ]

      expect { protocol.create_batch(requests) }.to raise_error(RubyLLM::Error, /one model/)
    end
  end

  describe '#validate_batch_requests!' do
    it 'rejects unsupported payload shapes' do
      expect { protocol.send(:validate_batch_requests!, [{ params: { messages: [] } }]) }
        .to raise_error(RubyLLM::Error, /responses payloads/)
    end
  end

  def uploaded_line
    JSON.parse(batch_calls[:uploads].first.first)
  end
end
