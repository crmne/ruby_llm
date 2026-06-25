# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Embeddings do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_interval_randomness: 0.5,
      retry_backoff_factor: 2,
      http_proxy: nil,
      faraday_adapter: :net_http,
      vertexai_location: 'us-central1',
      vertexai_project_id: 'test-project',
      vertexai_api_base: nil,
      vertexai_protocol: nil
    )
  end
  let(:provider) { RubyLLM::Providers::VertexAI.new(config) }
  let(:protocol) { RubyLLM::Providers::VertexAI::Gemini.new(provider) }

  describe '#render_embedding_payload' do
    it 'includes content for each instance' do
      payload = protocol.send(:render_embedding_payload, 'hello', model: 'gemini-embedding-001', dimensions: nil)

      expect(payload).to eq(instances: [{ content: 'hello' }])
    end

    it 'includes outputDimensionality when dimensions are provided' do
      payload = protocol.send(
        :render_embedding_payload,
        'hello',
        model: 'gemini-embedding-001',
        dimensions: 1536
      )

      expect(payload).to eq(
        instances: [{ content: 'hello' }],
        parameters: { outputDimensionality: 1536 }
      )
    end

    it 'includes task_type when provided' do
      payload = protocol.send(
        :render_embedding_payload,
        'hello',
        model: 'gemini-embedding-001',
        dimensions: 1536,
        task_type: 'SEMANTIC_SIMILARITY'
      )

      expect(payload).to eq(
        instances: [{ content: 'hello', task_type: 'SEMANTIC_SIMILARITY' }],
        parameters: { outputDimensionality: 1536 }
      )
    end

    it 'includes title when provided' do
      payload = protocol.send(
        :render_embedding_payload,
        'hello',
        model: 'gemini-embedding-001',
        dimensions: nil,
        task_type: 'RETRIEVAL_DOCUMENT',
        title: 'Doc title'
      )

      expect(payload).to eq(
        instances: [{ content: 'hello', task_type: 'RETRIEVAL_DOCUMENT', title: 'Doc title' }]
      )
    end

    it 'applies task_type to every instance in a batch' do
      payload = protocol.send(
        :render_embedding_payload,
        %w[one two],
        model: 'gemini-embedding-001',
        dimensions: nil,
        task_type: 'RETRIEVAL_QUERY'
      )

      expect(payload[:instances]).to eq(
        [
          { content: 'one', task_type: 'RETRIEVAL_QUERY' },
          { content: 'two', task_type: 'RETRIEVAL_QUERY' }
        ]
      )
    end
  end
end
