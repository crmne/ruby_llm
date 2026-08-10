# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI do
  include_context 'with configured RubyLLM'

  let(:provider) { described_class.new(RubyLLM.config) }

  describe '#batch_protocol_name_for' do
    it 'reads a Responses payload' do
      expect(provider.send(:batch_protocol_name_for, { input: 'hi' })).to eq(:responses)
      expect(provider.send(:batch_protocol_name_for, { 'input' => 'hi' })).to eq(:responses)
    end

    it 'reads a Chat Completions payload' do
      expect(provider.send(:batch_protocol_name_for, { messages: [] })).to eq(:chat_completions)
      expect(provider.send(:batch_protocol_name_for, { 'messages' => [] })).to eq(:chat_completions)
    end

    it 'refuses a payload it cannot route' do
      expect { provider.send(:batch_protocol_name_for, { prompt: 'hi' }) }.to raise_error(
        RubyLLM::Error, 'openai batch requests only support chat or responses payloads'
      )
    end
  end

  describe '#batch_protocol_for_endpoint' do
    it 'routes both spellings of each batch endpoint' do
      responses = provider.send(:batch_protocol_for_name, :responses)
      chat_completions = provider.send(:batch_protocol_for_name, :chat_completions)

      expect(provider.send(:batch_protocol_for_endpoint, '/v1/responses')).to eq(responses)
      expect(provider.send(:batch_protocol_for_endpoint, 'responses')).to eq(responses)
      expect(provider.send(:batch_protocol_for_endpoint, '/v1/chat/completions')).to eq(chat_completions)
      expect(provider.send(:batch_protocol_for_endpoint, 'chat/completions')).to eq(chat_completions)
    end

    it 'is nil for an endpoint it does not know' do
      expect(provider.send(:batch_protocol_for_endpoint, '/v1/embeddings')).to be_nil
      expect(provider.send(:batch_protocol_for_endpoint, nil)).to be_nil
    end
  end

  describe '#batch_protocol_for_stored_batch' do
    it 'falls back to the default protocol when the endpoint is unknown' do
      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:get).with('batches/batch_1').and_return(
        Struct.new(:body).new({ 'endpoint' => '/v1/embeddings' })
      )
      provider.instance_variable_set(:@connection, connection)

      expect(provider.send(:batch_protocol_for_stored_batch, 'batch_1')).to eq(provider.send(:batch_protocol))
    end

    it 'reads the protocol out of the stored endpoint' do
      connection = instance_double(RubyLLM::Connection)
      allow(connection).to receive(:get).with('batches/batch_1').and_return(
        Struct.new(:body).new({ 'endpoint' => '/v1/chat/completions' })
      )
      provider.instance_variable_set(:@connection, connection)

      expect(provider.send(:batch_protocol_for_stored_batch, 'batch_1')).to eq(
        provider.send(:batch_protocol_for_name, :chat_completions)
      )
    end
  end
end
