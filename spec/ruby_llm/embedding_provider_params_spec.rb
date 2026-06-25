# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedding provider params' do
  let(:config) { RubyLLM.config }
  let(:provider) { instance_double(RubyLLM::Providers::VertexAI, slug: 'vertexai') }
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'gemini-embedding-001') }

  before do
    allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])
    allow(RubyLLM).to receive(:instrument).and_yield({})
  end

  it 'forwards task_type to the provider embed call' do
    result = instance_double(RubyLLM::Embedding, model: 'gemini-embedding-001', input_tokens: 0, vectors: [0.1, 0.2])
    allow(provider).to receive(:embed).and_return(result)
    allow(provider).to receive(:class).and_return(RubyLLM::Providers::VertexAI)

    RubyLLM.embed(
      'hello',
      model: 'gemini-embedding-001',
      provider: :vertexai,
      dimensions: 1536,
      task_type: 'SEMANTIC_SIMILARITY'
    )

    expect(provider).to have_received(:embed).with(
      'hello',
      model: 'gemini-embedding-001',
      dimensions: 1536,
      task_type: 'SEMANTIC_SIMILARITY'
    )
  end

  it 'forwards title alongside task_type' do
    result = instance_double(RubyLLM::Embedding, model: 'gemini-embedding-001', input_tokens: 0, vectors: [0.1, 0.2])
    allow(provider).to receive(:embed).and_return(result)
    allow(provider).to receive(:class).and_return(RubyLLM::Providers::VertexAI)

    RubyLLM.embed(
      'hello',
      model: 'gemini-embedding-001',
      provider: :vertexai,
      task_type: 'RETRIEVAL_DOCUMENT',
      title: 'My Document'
    )

    expect(provider).to have_received(:embed).with(
      'hello',
      model: 'gemini-embedding-001',
      dimensions: nil,
      task_type: 'RETRIEVAL_DOCUMENT',
      title: 'My Document'
    )
  end
end
