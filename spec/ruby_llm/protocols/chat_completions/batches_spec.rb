# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Batches do
  let(:config) do
    RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:batch_calls) { { posts: [], uploads: [] } }
  let(:protocol) do
    RubyLLM::Providers::OpenAI.batch_protocols.fetch(:chat_completions).allocate.tap do |instance|
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
    it 'uploads JSONL through the provider files API and creates a Chat Completions batch' do
      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'gpt-4o-mini-search-preview',
                                params: {
                                  model: 'gpt-4o-mini-search-preview',
                                  messages: [{ role: 'user', content: 'Hi' }],
                                  stream: false
                                }
                              }
                            ])

      expect(batch_calls[:uploads].last.last).to include(purpose: 'batch', filename: 'ruby_llm_batch.jsonl')
      expect(batch_calls[:posts].last).to eq([
                                               'batches',
                                               {
                                                 input_file_id: 'file_123',
                                                 endpoint: '/v1/chat/completions',
                                                 completion_window: '24h'
                                               }
                                             ])
      expect(uploaded_line).to include('url' => '/v1/chat/completions')
      expect(uploaded_line.fetch('body')).not_to have_key('stream')
    end
  end

  describe '#validate_batch_requests!' do
    it 'rejects unsupported payload shapes' do
      expect { protocol.send(:validate_batch_requests!, [{ params: { input: 'hi' } }]) }
        .to raise_error(RubyLLM::Error, /chat completion payloads/)
    end
  end

  describe '#single_batch_model!' do
    it 'rejects mixed-model batches' do
      requests = [
        { custom_id: '0', model: 'gpt-5-nano', params: { input: 'hi' } },
        { custom_id: '1', model: 'gpt-4o', params: { input: 'hi' } }
      ]

      expect { protocol.send(:single_batch_model!, requests, 'openai') }
        .to raise_error(RubyLLM::Error, /one model/)
    end
  end

  describe '#parse_batch_response' do
    it 'normalizes OpenAI batch attributes' do
      attributes = protocol.send(:parse_batch_response, {
                                   'id' => 'batch_123',
                                   'status' => 'completed',
                                   'request_counts' => { 'total' => 2 }
                                 })

      expect(attributes).to eq(
        id: 'batch_123',
        status: 'completed',
        completed: true,
        request_counts: { 'total' => 2 }
      )
    end
  end

  describe '#parse_batch_completion_response' do
    it 'parses chat completion rows with the chat completions parser' do
      body = {
        'model' => 'gpt-5-nano',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello'
            }
          }
        ],
        'usage' => { 'prompt_tokens' => 2, 'completion_tokens' => 1 }
      }

      message = protocol.send(:parse_batch_completion_response, body)

      expect(message.content).to eq('Hello')
      expect(message.model_id).to eq('gpt-5-nano')
      expect(message.input_tokens).to eq(2)
      expect(message.raw).to eq(body)
    end
  end

  def uploaded_line
    JSON.parse(batch_calls[:uploads].first.first)
  end
end
