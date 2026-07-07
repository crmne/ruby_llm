# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::EmbeddingProtocol do
  let(:config) { RubyLLM::Configuration.new }
  let(:connection) { instance_double(RubyLLM::Connection) }
  let(:provider) do
    instance_double(
      RubyLLM::Providers::Bedrock,
      config: config,
      connection: connection,
      sign_headers: { 'Authorization' => 'signed' }
    )
  end

  describe RubyLLM::Providers::Bedrock::TitanTextEmbeddings do
    subject(:protocol) { described_class.new(provider) }

    it 'renders Titan text embedding payloads' do
      payload = protocol.send(
        :render_embedding_payload,
        'Ruby',
        dimensions: 256,
        provider_options: { embeddingTypes: ['float'] }
      )

      expect(payload).to eq(
        inputText: 'Ruby',
        dimensions: 256,
        normalize: true,
        embeddingTypes: ['float']
      )
    end

    it 'parses Titan typed embedding responses' do
      response = instance_double(
        Faraday::Response,
        body: { 'embeddingsByType' => { 'float' => [0.1, 0.2] }, 'inputTextTokenCount' => 3 }
      )

      embedding = protocol.send(
        :parse_single_embedding_responses,
        [response],
        model: 'amazon.titan-embed-text-v2:0',
        text: 'Ruby'
      )

      expect(embedding.vectors).to eq([0.1, 0.2])
      expect(embedding.input_tokens).to eq(3)
    end
  end

  describe RubyLLM::Providers::Bedrock::TitanMultimodalEmbeddings do
    subject(:protocol) { described_class.new(provider) }

    it 'renders Titan multimodal embedding payloads' do
      payload = protocol.send(:render_embedding_payload, 'Ruby', dimensions: 384, provider_options: {})

      expect(payload).to eq(
        inputText: 'Ruby',
        embeddingConfig: { outputEmbeddingLength: 384 }
      )
    end

    it 'allows Titan multimodal image options without text' do
      payload = protocol.send(
        :render_embedding_payload,
        nil,
        dimensions: nil,
        provider_options: { inputImage: 'base64-image' }
      )

      expect(payload).to eq(inputImage: 'base64-image')
    end
  end

  describe RubyLLM::Providers::Bedrock::CohereEmbeddings do
    subject(:protocol) { described_class.new(provider) }

    it 'renders Cohere v4 embedding payloads with Bedrock-specific options' do
      payload = protocol.send(
        :render_embedding_payload,
        %w[Ruby Python],
        model: 'us.cohere.embed-v4:0',
        dimensions: 512,
        provider_options: { input_type: 'search_query', embedding_types: ['float'] }
      )

      expect(payload).to eq(
        input_type: 'search_query',
        texts: %w[Ruby Python],
        output_dimension: 512,
        embedding_types: ['float']
      )
    end

    it 'maps task_type to input_type' do
      payload = protocol.send(
        :render_embedding_payload,
        'Ruby',
        model: 'us.cohere.embed-v4:0',
        dimensions: nil,
        task_type: 'search_query',
        provider_options: {}
      )

      expect(payload).to eq(input_type: 'search_query', texts: ['Ruby'])
    end

    it 'defaults input_type to search_document without a task_type' do
      payload = protocol.send(
        :render_embedding_payload,
        'Ruby',
        model: 'us.cohere.embed-v4:0',
        dimensions: nil,
        provider_options: {}
      )

      expect(payload).to eq(input_type: 'search_document', texts: ['Ruby'])
    end

    it 'allows Cohere image options without text' do
      payload = protocol.send(
        :render_embedding_payload,
        nil,
        model: 'us.cohere.embed-v4:0',
        dimensions: nil,
        provider_options: { input_type: 'image', images: ['base64-image'] }
      )

      expect(payload).to eq(input_type: 'image', images: ['base64-image'])
    end

    it 'rejects custom dimensions for Cohere v3' do
      expect do
        protocol.send(
          :render_embedding_payload,
          'Ruby',
          model: 'cohere.embed-english-v3',
          dimensions: 512,
          provider_options: {}
        )
      end.to raise_error(RubyLLM::Error, /does not support custom dimensions/)
    end

    it 'parses Cohere float embedding responses' do
      response = instance_double(Faraday::Response, body: { 'embeddings' => [[0.1, 0.2], [0.3, 0.4]] })

      embedding = protocol.send(:parse_embedding_response, response, model: 'cohere.embed-english-v3', text: %w[a b])

      expect(embedding.vectors).to eq([[0.1, 0.2], [0.3, 0.4]])
      expect(embedding.model).to eq('cohere.embed-english-v3')
    end

    it 'parses Cohere typed embedding responses' do
      response = instance_double(
        Faraday::Response,
        body: { 'embeddings' => { 'float' => [[0.1, 0.2]], 'int8' => [[1, 2]] } }
      )

      embedding = protocol.send(:parse_embedding_response, response, model: 'us.cohere.embed-v4:0', text: 'Ruby')

      expect(embedding.vectors).to eq([0.1, 0.2])
    end
  end
end
