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
        params: {
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
      expect(message.model_id).to eq('meta/llama-3.3-70b-instruct-maas')
    end
  end
end
