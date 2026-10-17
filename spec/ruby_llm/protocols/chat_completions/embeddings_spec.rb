# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Embeddings do
  let(:config) do
    RubyLLM::Configuration.new.tap { |configuration| configuration.openai_api_key = 'test' }
  end
  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:protocol) do
    RubyLLM::Providers::OpenAI.protocols.fetch(:chat_completions).allocate.tap do |instance|
      instance.instance_variable_set(:@provider, provider)
    end
  end

  def response_for(rows, usage: { 'prompt_tokens' => 8 })
    Struct.new(:body).new({ 'data' => rows, 'usage' => usage })
  end

  def parse(rows, text:)
    protocol.send(:parse_embedding_response, response_for(rows), model: 'bge-m3', text: text)
  end

  describe '#parse_embedding_response' do
    it 'reports no sparse vectors when the server returns dense ones only' do
      embedding = parse([{ 'embedding' => [0.1, 0.2] }], text: 'Ruby')

      expect(embedding.vectors).to eq([0.1, 0.2])
      expect(embedding.sparse_vectors).to be_nil
    end

    it 'reads the sparse vector BGE-M3 returns as lexical_weights' do
      embedding = parse([{ 'embedding' => [0.1], 'lexical_weights' => { '1037' => 0.25, '2003' => 0.5 } }],
                        text: 'Ruby')

      expect(embedding.sparse_vectors).to eq({ 1037 => 0.25, 2003 => 0.5 })
    end

    it 'reads the sparse vector other servers return as sparse_embedding' do
      embedding = parse([{ 'embedding' => [0.1], 'sparse_embedding' => { '42' => 1 } }], text: 'Ruby')

      expect(embedding.sparse_vectors).to eq({ 42 => 1.0 })
    end

    it 'shapes sparse vectors like dense ones when an array of texts was embedded' do
      embedding = parse(
        [
          { 'embedding' => [0.1], 'lexical_weights' => { '1' => 0.5 } },
          { 'embedding' => [0.2], 'lexical_weights' => { '2' => 0.75 } }
        ],
        text: %w[Ruby Python]
      )

      expect(embedding.vectors).to eq([[0.1], [0.2]])
      expect(embedding.sparse_vectors).to eq([{ 1 => 0.5 }, { 2 => 0.75 }])
    end

    it 'keeps the array shape when only some rows carry a sparse vector' do
      embedding = parse(
        [{ 'embedding' => [0.1], 'lexical_weights' => { '1' => 0.5 } }, { 'embedding' => [0.2] }],
        text: %w[Ruby Python]
      )

      expect(embedding.sparse_vectors).to eq([{ 1 => 0.5 }, nil])
    end

    it 'pairs each vector with the input its row index names' do
      embedding = parse(
        [
          { 'index' => 2, 'embedding' => [0.3], 'lexical_weights' => { '3' => 0.75 } },
          { 'index' => 0, 'embedding' => [0.1], 'lexical_weights' => { '1' => 0.25 } },
          { 'index' => 1, 'embedding' => [0.2], 'lexical_weights' => { '2' => 0.5 } }
        ],
        text: %w[Ruby Python Elixir]
      )

      expect(embedding.vectors).to eq([[0.1], [0.2], [0.3]])
      expect(embedding.sparse_vectors).to eq([{ 1 => 0.25 }, { 2 => 0.5 }, { 3 => 0.75 }])
    end

    [[0, 0], [0, 2], [1], [nil, 0]].each do |positions|
      it "raises when the row positions are #{positions.inspect}" do
        rows = positions.map { |position| { 'index' => position, 'embedding' => [0.1] } }

        expect { parse(rows, text: %w[Ruby Python]) }
          .to raise_error(RubyLLM::Error, 'Invalid or duplicate embedding record positions')
      end
    end
  end
end
