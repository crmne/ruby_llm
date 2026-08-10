# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::ChatCompletions::Batches do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      vertexai_batch_gcs_uri: 'gs://ruby-llm-batches/test',
      faraday_adapter: :net_http
    )
  end
  let(:provider) { instance_double(RubyLLM::Providers::VertexAI, slug: 'vertexai') }
  let(:protocol) do
    RubyLLM::Providers::VertexAI.batch_protocols.fetch(:chat_completions).allocate.tap do |instance|
      instance.instance_variable_set(:@config, config)
      instance.instance_variable_set(:@provider, provider)
    end
  end

  describe '#vertex_batch_request' do
    it 'uses OpenAI JSONL rows for MaaS chat models' do
      request = {
        custom_id: '2',
        payload: {
          model: 'meta/llama-3.3-70b-instruct-maas',
          messages: [{ role: 'user', content: 'Hi' }],
          stream: false
        }
      }

      expect(protocol.send(:vertex_batch_request, request)).to eq(
        custom_id: '2',
        method: 'POST',
        url: '/v1/chat/completions',
        body: {
          model: 'meta/llama-3.3-70b-instruct-maas',
          messages: [{ role: 'user', content: 'Hi' }]
        }
      )
    end
  end

  describe '#vertex_batch_model_path' do
    it 'builds a publisher model path from publisher/model ids' do
      allow(provider).to receive(:model_path)
        .with('llama-3.3-70b-instruct-maas', publisher: 'meta')
        .and_return('projects/test/locations/us-central1/publishers/meta/models/llama-3.3-70b-instruct-maas')

      expect(protocol.send(:vertex_batch_model_path, 'meta/llama-3.3-70b-instruct-maas'))
        .to eq('projects/test/locations/us-central1/publishers/meta/models/llama-3.3-70b-instruct-maas')
    end
  end

  describe '#parse_vertex_batch_result' do
    it 'parses successful chat completion responses by custom id' do
      line = {
        'custom_id' => '2',
        'response' => {
          'choices' => [
            { 'message' => { 'role' => 'assistant', 'content' => 'Hello' } }
          ],
          'usage' => { 'prompt_tokens' => 2, 'completion_tokens' => 1 },
          'model' => 'meta/llama-3.3-70b-instruct-maas'
        }
      }

      index, message = protocol.send(:parse_vertex_batch_result, line, 0)

      expect(index).to eq(2)
      expect(message.content).to eq('Hello')
      expect(message.model).to eq('meta/llama-3.3-70b-instruct-maas')
    end
  end

  describe '#validate_batch_requests!' do
    it 'accepts chat completion payloads' do
      requests = [{ payload: { messages: [] } }, { payload: { 'messages' => [] } }]

      expect { protocol.send(:validate_batch_requests!, requests) }.not_to raise_error
    end

    it 'refuses anything else' do
      expect { protocol.send(:validate_batch_requests!, [{ payload: { input: 'hi' } }]) }.to raise_error(
        RubyLLM::Error, 'vertexai MaaS batch requests require chat completion payloads'
      )
    end
  end

  describe '#vertex_batch_model_path validation' do
    it 'splits the publisher off the model id' do
      allow(provider).to receive(:model_path).with('llama-3.3-70b-instruct-maas', publisher: 'meta')
                                             .and_return('projects/p/publishers/meta/models/llama')

      expect(protocol.send(:vertex_batch_model_path, 'meta/llama-3.3-70b-instruct-maas')).to eq(
        'projects/p/publishers/meta/models/llama'
      )
    end

    it 'refuses a bare model id' do
      expect { protocol.send(:vertex_batch_model_path, 'gemini-2.5-flash') }.to raise_error(
        RubyLLM::Error, 'vertexai MaaS batch requests require publisher/model ids'
      )
    end
  end

  describe '#parse_vertex_batch_result envelopes' do
    it 'unwraps a response body envelope' do
      line = {
        'custom_id' => '1',
        'response' => {
          'body' => {
            'model' => 'meta/llama-3.3-70b-instruct-maas',
            'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Hi' } }]
          }
        }
      }

      index, message = protocol.send(:parse_vertex_batch_result, line, 0)

      expect(index).to eq(1)
      expect(message.content).to eq('Hi')
    end

    it 'warns and returns no message for a failed row' do
      allow(RubyLLM.logger).to receive(:warn)

      index, message = protocol.send(
        :parse_vertex_batch_result, { 'custom_id' => '5', 'status' => { 'message' => 'quota exceeded' } }, 0
      )

      expect(index).to eq(5)
      expect(message).to be_nil
      expect(RubyLLM.logger).to have_received(:warn).with('Batch request 5 failed: quota exceeded')
    end
  end
end
