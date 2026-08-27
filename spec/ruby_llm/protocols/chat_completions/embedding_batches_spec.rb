# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::EmbeddingBatches do
  let(:config) do
    RubyLLM::Configuration.new.tap { |config| config.openai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:connection) { instance_double(RubyLLM::Connection) }
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
  end

  def uploaded_line
    JSON.parse(batch_calls[:uploads].first.first)
  end
end
