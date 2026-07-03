# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Embeddings do
  let(:provider) { instance_double(RubyLLM::Providers::VertexAI, model_path: 'publishers/google/models/gemini-embedding-001') }
  let(:protocol) do
    Object.new.extend(described_class).tap do |object|
      object.instance_variable_set(:@provider, provider)
    end
  end

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

    it 'uses params for VertexAI task_type and title' do
      payload = protocol.send(
        :render_embedding_payload,
        %w[one two],
        model: 'gemini-embedding-001',
        dimensions: nil,
        params: { task_type: 'RETRIEVAL_DOCUMENT', title: 'Docs' }
      )

      expect(payload).to eq(
        instances: [
          { content: 'one', task_type: 'RETRIEVAL_DOCUMENT', title: 'Docs' },
          { content: 'two', task_type: 'RETRIEVAL_DOCUMENT', title: 'Docs' }
        ]
      )
    end

    it 'merges remaining params into the payload' do
      payload = protocol.send(
        :render_embedding_payload,
        'hello',
        model: 'gemini-embedding-001',
        dimensions: nil,
        params: { parameters: { autoTruncate: false } }
      )

      expect(payload).to eq(
        instances: [{ content: 'hello' }],
        parameters: { autoTruncate: false }
      )
    end
  end
end
