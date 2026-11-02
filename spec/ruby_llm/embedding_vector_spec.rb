# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Embedding do
  let(:model) { 'text-embedding-3-small' }

  describe '#vector' do
    it 'returns the vector of a single text' do
      expect(described_class.new(vectors: [0.1, 0.2], model:).vector).to eq([0.1, 0.2])
    end

    it 'returns the only vector of a one-text array' do
      expect(described_class.new(vectors: [[0.1, 0.2]], model:).vector).to eq([0.1, 0.2])
    end

    it 'raises for several vectors rather than guessing' do
      embedding = described_class.new(vectors: [[0.1], [0.2]], model:)

      expect { embedding.vector }.to raise_error(RubyLLM::Error, /holds 2 vectors; read them with #vectors/)
    end

    it 'counts a row the provider left empty' do
      embedding = described_class.new(vectors: [[0.1], nil], model:)

      expect { embedding.vector }.to raise_error(RubyLLM::Error, /holds 2 vectors/)
    end

    it 'leaves vectors as they are' do
      expect(described_class.new(vectors: [[0.1], [0.2]], model:).vectors).to eq([[0.1], [0.2]])
    end
  end
end
