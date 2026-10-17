# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Embeddings do
  let(:protocol) { Object.new.extend(described_class) }

  describe '#render_embedding_payload' do
    it 'renders one request per text' do
      payload = protocol.send(:render_embedding_payload, %w[one two], model: 'gemini-embedding-001', dimensions: nil)

      expect(payload).to eq(
        requests: [
          { model: 'models/gemini-embedding-001', content: { parts: [{ text: 'one' }] } },
          { model: 'models/gemini-embedding-001', content: { parts: [{ text: 'two' }] } }
        ]
      )
    end

    it 'adds taskType and title to each request' do
      payload = protocol.send(
        :render_embedding_payload,
        %w[one two],
        model: 'gemini-embedding-001',
        dimensions: nil,
        task_type: 'RETRIEVAL_DOCUMENT',
        title: 'Docs'
      )

      expect(payload).to eq(
        requests: [
          {
            model: 'models/gemini-embedding-001',
            content: { parts: [{ text: 'one' }] },
            taskType: 'RETRIEVAL_DOCUMENT',
            title: 'Docs'
          },
          {
            model: 'models/gemini-embedding-001',
            content: { parts: [{ text: 'two' }] },
            taskType: 'RETRIEVAL_DOCUMENT',
            title: 'Docs'
          }
        ]
      )
    end

    it 'lets provider options override the rendered requests' do
      payload = protocol.send(
        :render_embedding_payload,
        'one',
        model: 'gemini-embedding-001',
        dimensions: nil,
        task_type: 'RETRIEVAL_DOCUMENT',
        provider_options: { requests: [{ model: 'models/gemini-embedding-001', taskType: 'RETRIEVAL_QUERY' }] }
      )

      expect(payload).to eq(
        requests: [{ model: 'models/gemini-embedding-001', taskType: 'RETRIEVAL_QUERY' }]
      )
    end
  end

  describe '#parse_embedding_response' do
    def response_for(body)
      Struct.new(:body).new(body)
    end

    it 'reads the input tokens from the usage metadata' do
      response = response_for(
        'embeddings' => [{ 'values' => [0.1, 0.2] }],
        'usageMetadata' => { 'promptTokenCount' => 8 }
      )

      embedding = protocol.send(:parse_embedding_response, response, model: 'gemini-embedding-2', text: 'Ruby')

      expect(embedding.vectors).to eq([0.1, 0.2])
      expect(embedding.tokens.input).to eq(8)
    end

    it 'leaves the input tokens unknown when the response reports no usage' do
      response = response_for('embeddings' => [{ 'values' => [0.1, 0.2] }])

      embedding = protocol.send(:parse_embedding_response, response, model: 'gemini-embedding-001', text: 'Ruby')

      expect(embedding.tokens.input).to be_nil
    end
  end
end
