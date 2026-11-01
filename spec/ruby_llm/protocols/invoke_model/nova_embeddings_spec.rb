# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::InvokeModel::NovaEmbeddings do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider) }

  describe 'request shape' do
    it 'renders a single-embedding payload with a truncating text input' do
      payload = protocol.send(:render_embedding_payload, 'Hello', dimensions: 256, task_type: nil,
                                                                  provider_options: {})

      expect(payload).to eq(
        taskType: 'SINGLE_EMBEDDING',
        singleEmbeddingParams: {
          embeddingPurpose: 'GENERIC_INDEX',
          embeddingDimension: 256,
          text: { truncationMode: 'END', value: 'Hello' }
        }
      )
    end

    it 'omits embeddingDimension without dimensions' do
      payload = protocol.send(:render_embedding_payload, 'Hello', dimensions: nil, task_type: nil,
                                                                  provider_options: {})

      expect(payload[:singleEmbeddingParams]).not_to have_key(:embeddingDimension)
    end

    it 'sends task_type as the embedding purpose' do
      payload = protocol.send(:render_embedding_payload, 'Hello', dimensions: nil, task_type: 'TEXT_RETRIEVAL',
                                                                  provider_options: {})

      expect(payload[:singleEmbeddingParams][:embeddingPurpose]).to eq('TEXT_RETRIEVAL')
    end

    it 'deep merges provider options' do
      payload = protocol.send(:render_embedding_payload, 'Hello', dimensions: nil, task_type: nil,
                                                                  provider_options: {
                                                                    singleEmbeddingParams: {
                                                                      text: { truncationMode: 'NONE' }
                                                                    }
                                                                  })

      expect(payload[:singleEmbeddingParams][:text]).to eq(truncationMode: 'NONE', value: 'Hello')
    end
  end

  describe 'response shape' do
    it 'reads the embedding out of the embeddings array' do
      body = { 'embeddings' => [{ 'embeddingType' => 'TEXT', 'embedding' => [0.1, 0.2] }] }

      expect(protocol.send(:parse_embedding, body)).to eq([0.1, 0.2])
    end
  end

  describe 'usage' do
    it 'reads the input tokens from the header Nova sends them in' do
      headers = Faraday::Utils::Headers.new('X-Amzn-Bedrock-Input-Token-Count' => '7')
      response = instance_double(Faraday::Response, headers:, body: { 'embeddings' => [{ 'embedding' => [0.1] }] })

      embedding = protocol.send(:parse_single_embedding_responses, [response], model: 'nova', text: 'Hello')

      expect(embedding.tokens.input).to eq(7)
    end

    it 'keeps the count unknown when the header is absent' do
      response = instance_double(Faraday::Response, headers: Faraday::Utils::Headers.new,
                                                    body: { 'embeddings' => [{ 'embedding' => [0.1] }] })

      embedding = protocol.send(:parse_single_embedding_responses, [response], model: 'nova', text: 'Hello')

      expect(embedding.tokens.input).to be_nil
    end
  end
end
