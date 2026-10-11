# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::EmbeddingBatches do
  let(:config) do
    RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:connection) { instance_double(RubyLLM::Transport::Connection) }
  let(:batch_calls) { { posts: [], uploads: [] } }
  let(:protocol) do
    RubyLLM::Providers::OpenAI.protocols.fetch(:embeddings).allocate.tap do |instance|
      instance.instance_variable_set(:@provider, provider)
      instance.instance_variable_set(:@connection, connection)
    end
  end

  before do
    allow(provider).to receive(:upload_file) do |io, **options|
      batch_calls[:uploads] << [io.string, options]
      instance_double(RubyLLM::UploadedFile, id: 'file_123')
    end
    allow(connection).to receive(:post) do |url, body|
      batch_calls[:posts] << [url, body]
      Struct.new(:body).new({ 'id' => 'batch_123', 'status' => 'validating' })
    end
  end

  describe '#create_batch' do
    it 'uploads JSONL through the provider files API and creates an embeddings batch' do
      protocol.create_batch([
                              {
                                custom_id: '0',
                                model: 'text-embedding-3-small',
                                payload: { model: 'text-embedding-3-small', input: 'Ruby', dimensions: 256 }
                              }
                            ])

      expect(batch_calls[:uploads].last.last).to include(purpose: 'batch', filename: 'ruby_llm_batch.jsonl')
      expect(batch_calls[:posts].last).to eq([
                                               'batches',
                                               {
                                                 input_file_id: 'file_123',
                                                 endpoint: '/v1/embeddings',
                                                 completion_window: '24h'
                                               }
                                             ])
      expect(uploaded_line).to eq(
        'custom_id' => '0',
        'method' => 'POST',
        'url' => '/v1/embeddings',
        'body' => { 'model' => 'text-embedding-3-small', 'input' => 'Ruby', 'dimensions' => 256 }
      )
    end
  end

  describe '#validate_batch_requests!' do
    it 'rejects unsupported payload shapes' do
      expect { protocol.send(:validate_batch_requests!, [{ payload: { messages: [] } }]) }
        .to raise_error(RubyLLM::Error, /embedding payloads/)
    end
  end

  describe '#parse_batch_result' do
    it 'maps an output line back by custom_id and parses an Embedding' do
      line = {
        'custom_id' => '1',
        'response' => {
          'status_code' => 200,
          'body' => {
            'object' => 'list',
            'model' => 'text-embedding-3-small',
            'data' => [{ 'object' => 'embedding', 'index' => 0, 'embedding' => [0.1, -0.2, 0.3] }],
            'usage' => { 'prompt_tokens' => 5, 'total_tokens' => 5 }
          }
        }
      }

      index, embedding = protocol.send(:parse_batch_result, line)

      expect(index).to eq(1)
      expect(embedding).to be_a(RubyLLM::Embedding)
      expect(embedding.vectors).to eq([0.1, -0.2, 0.3])
      expect(embedding.model).to eq('text-embedding-3-small')
      expect(embedding.tokens.input).to eq(5)
    end

    it 'orders embedding rows by the index that names their input' do
      index, embedding = protocol.send(:parse_batch_result, embedding_line([0.1, 0.2], positions: [1, 0]))

      expect(index).to eq(3)
      expect(embedding.vectors).to eq([[0.2], [0.1]])
    end

    [[0, 0], [0, 2], [-1, 0], [nil, 0], ['0', 1], [0.0, 1], [1], [0, 1, 2, 2]].each do |positions|
      it "fails the embedding result with invalid positions #{positions.inspect}" do
        line = embedding_line([0.1] * positions.size, positions:)
        index, embedding, failure = protocol.send(:parse_batch_result, line)

        expect(index).to eq(3)
        expect(embedding).to be_nil
        expect(failure).to eq(:failed)
      end
    end

    it 'fails the embedding result when a row carries no position' do
      line = embedding_line([0.1, 0.2])
      line['response']['body']['data'].first.delete('index')

      _index, embedding, failure = protocol.send(:parse_batch_result, line)

      expect(embedding).to be_nil
      expect(failure).to eq(:failed)
    end

    it 'fails the embedding result when a row is not a record' do
      line = embedding_line([0.1, 0.2])
      line['response']['body']['data'][0] = 'not a record'

      _index, embedding, failure = protocol.send(:parse_batch_result, line)

      expect(embedding).to be_nil
      expect(failure).to eq(:failed)
    end
  end

  def embedding_line(vectors, positions: vectors.each_index.to_a)
    rows = vectors.zip(positions).map { |vector, position| { 'index' => position, 'embedding' => [vector] } }
    {
      'custom_id' => '3',
      'response' => {
        'status_code' => 200,
        'body' => {
          'object' => 'list',
          'model' => 'text-embedding-3-small',
          'data' => rows.reverse,
          'usage' => { 'prompt_tokens' => 5, 'total_tokens' => 5 }
        }
      }
    }
  end

  def uploaded_line
    JSON.parse(batch_calls[:uploads].first.first)
  end
end
