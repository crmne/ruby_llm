# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Embeddings do
  let(:test_class) do
    Class.new do
      include RubyLLM::Providers::VertexAI::Embeddings

      attr_reader :config

      def initialize(config)
        @config = config
      end
    end
  end

  let(:config) do
    double( # rubocop:disable RSpec/VerifiedDoubles
      'config',
      vertexai_project_id: 'test-project',
      vertexai_location: 'us-central1'
    )
  end

  let(:embeddings) do
    test_class.new(config)
  end

  describe '#embedding_url' do
    it 'constructs the correct URL' do
      url = embeddings.send(:embedding_url, model: 'multimodalembedding')
      expect(url).to eq(
        'projects/test-project/locations/us-central1/publishers/google/models/multimodalembedding:predict'
      )
    end
  end

  describe '#render_embedding_payload' do
    context 'with text only' do
      it 'renders single text payload with a text embedding model' do
        payload = embeddings.send(:render_embedding_payload, 'Hello!', model: 'gemini-embedding-001')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }])
      end

      it 'renders single text payload with a multimodal embedding model' do
        payload = embeddings.send(:render_embedding_payload, 'Hello!', model: 'multimodalembedding')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }])
      end

      it 'renders multiple batch text payloads' do
        payload = embeddings.send(:render_embedding_payload, ['Hello!', 'Hi there!'], model: 'text-embedding-005')
        expect(payload[:instances]).to eq([{ text: 'Hello!' }, { text: 'Hi there!' }])
      end
    end

    context 'with multimodal content payload' do
      it 'renders payload with multimodal content' do
        image_data = 'fake_image_data'
        video_data = 'fake_video_data'

        payload = embeddings.send(
          :render_embedding_payload,
          'Test multimodal input',
          model: 'multimodalembedding',
          image: image_data,
          video: video_data
        )
        expect(payload[:instances].first[:text]).to eq('Test multimodal input')
        expect(payload[:instances].first).to have_key(:image)
        expect(payload[:instances].first).to have_key(:video)
      end

      it 'renders payload wtih dimensions parameter' do
        payload = embeddings.send(
          :render_embedding_payload,
          'Hello!',
          model: 'multimodalembedding',
          dimensions: 512
        )
        expect(payload[:parameters]).to eq({ outputDimensionality: 512 })
      end
    end
  end

  describe '#parse_embedding_response' do
    context 'with text only embeddings' do
      it 'parses text only embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              'embeddings' => {
                'statistics' => {
                  'truncated' => false,
                  'token_count' => 6
                },
                'values' => ['...']
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'gemini-embedding-001',
          text: 'Hello!'
        )
        expect(embedding.vectors).to eq(['...'])
        expect(embedding.model).to eq('gemini-embedding-001')
      end

      it 'parses batch text embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              {
                'embeddings' => {
                  'statistics' => {
                    'token_count' => 8,
                    'truncated' => false
                  },
                  'values' => ['0.1,....']
                }
              },
              {
                'embeddings' => {
                  'statistics' => {
                    'token_count' => 3,
                    'truncated' => false
                  },
                  'values' => ['0.2,....']
                }
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'text-embedding-004',
          text: ['Hello!', 'Hi there!']
        )
        expect(embedding.vectors).to eq([['0.1,....'], ['0.2,....']])
        expect(embedding.model).to eq('text-embedding-004')
      end
    end

    context 'with multimodal embeddings' do
      it 'parses multimodal embedding response' do
        embedding_response = instance_double(
          Faraday::Response, body: {
            'predictions' => [
              {
                'textEmbedding' => ['0.1,....'],
                'imageEmbedding' => ['0.2,....'],
                'videoEmbedding' => ['0.3,....']
              }
            ]
          }
        )
        embedding = embeddings.send(
          :parse_embedding_response,
          embedding_response,
          model: 'multimodalembedding',
          text: 'Multimodal input'
        )
        expect(embedding.vectors).to eq(
          {
            text: ['0.1,....'],
            image: ['0.2,....'],
            video: ['0.3,....']
          }
        )
        expect(embedding.model).to eq('multimodalembedding')
      end
    end
  end
end
