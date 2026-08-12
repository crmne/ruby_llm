# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::InvokeModel::CohereEmbeddings do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }
  let(:protocol) { described_class.new(provider) }

  describe 'request shape' do
    it 'renders texts with a default input type' do
      payload = protocol.send(:render_embedding_payload, %w[one two], model: 'us.cohere.embed-v4:0',
                                                                      dimensions: nil, provider_options: {})

      expect(payload).to eq(input_type: 'search_document', texts: %w[one two])
    end

    it 'sends custom dimensions as output_dimension on Embed v4' do
      payload = protocol.send(:render_embedding_payload, 'one', model: 'us.cohere.embed-v4:0',
                                                                dimensions: 512, provider_options: {})

      expect(payload[:output_dimension]).to eq(512)
    end

    it 'rejects custom dimensions on Embed v3' do
      expect do
        protocol.send(:render_embedding_payload, 'one', model: 'cohere.embed-english-v3',
                                                        dimensions: 512, provider_options: {})
      end.to raise_error(RubyLLM::Error, /does not support custom dimensions/)
    end
  end

  describe 'response shape' do
    it 'reads Embed v4 embeddings keyed by type' do
      response = instance_double(
        Faraday::Response,
        body: { 'embeddings' => { 'float' => [[0.1, 0.2]] }, 'response_type' => 'embeddings_by_type' }
      )

      embedding = protocol.send(:parse_embedding_response, response, model: 'us.cohere.embed-v4:0', text: 'one')

      expect(embedding.vectors).to eq([0.1, 0.2])
    end

    it 'reads Embed v3 embeddings from the flat array' do
      response = instance_double(Faraday::Response, body: { 'embeddings' => [[0.1, 0.2]] })

      embedding = protocol.send(:parse_embedding_response, response, model: 'cohere.embed-english-v3', text: 'one')

      expect(embedding.vectors).to eq([0.1, 0.2])
    end
  end
end
