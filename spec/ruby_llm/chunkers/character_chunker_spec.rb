# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::CharacterChunker do
  describe '#chunk' do
    let(:chunker) { described_class.new(chunk_size: 10, overlap: 2) }

    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'splits content into overlapping chunks' do
      content = 'abcdefghijklmnopqrstuvwxyz'
      chunks = chunker.chunk(content)

      expect(chunks).to eq(%w[abcdefghij ijklmnopqr qrstuvwxyz])
    end

    it 'handles chunking when there is no overlap' do
      chunker = described_class.new(chunk_size: 10, overlap: 0)
      content = 'abcdefghijklmnopqrstuvwxyz'
      chunks = chunker.chunk(content)
      expect(chunks).to eq(%w[abcdefghij klmnopqrst uvwxyz])
    end

    it 'handles content smaller than chunk size' do
      content = 'small'
      chunks = chunker.chunk(content)
      expect(chunks).to eq(['small'])
    end
  end
end
