# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::SentenceChunker do
  let(:chunker) { described_class.new(min_size: 10, max_size: 50) }

  describe '#chunk' do
    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'splits content into sentences' do
      content = 'First sentence. Second sentence! Third sentence? Fourth sentence.'
      chunks = chunker.chunk(content)

      expect(chunks).to eq(['First sentence. Second sentence! Third sentence?', 'Fourth sentence.'])
    end

    it 'handles abbreviations correctly' do
      content = 'Mr. Smith went to Dr. Jones. They discussed i.e. medical issues.'
      chunks = chunker.chunk(content)

      expect(chunks).to eq([
                             'Mr. Smith went to Dr. Jones.', 'They discussed i.e. medical issues.'
                           ])
    end

    it 'combines short sentences' do
      chunker = described_class.new(max_size: 70)
      content = 'Hi. How are you? I am good. This is a much longer sentence that should be in its own chunk.'
      chunks = chunker.chunk(content)

      expect(chunks).to eq([
                             'Hi. How are you? I am good.',
                             'This is a much longer sentence that should be in its own chunk.'
                           ])
    end

    it 'respects max_size parameter' do
      chunker = described_class.new(max_size: 20)
      content = 'This is a longer first sentence. This is another longer sentence. Short one.'

      chunks = chunker.chunk(content)
      chunks.each do |chunk|
        expect(chunk.length).to be <= 20
      end
    end

    it 'handles complex punctuation' do
      content = 'The U.S. is big! The U.K. is smaller. Dr. Smith (M.D., Ph.D.) wrote i.e. a book.'
      chunks = chunker.chunk(content)

      expect(chunks.first).to include('The U.S. is big!')
      expect(chunks.first).to include('The U.K. is smaller.')
    end

    it 'preserves quotation marks' do
      content = 'He said "Hello there!" Then she replied "Hi!"'
      expect(chunker.chunk(content)).to eq([content])
    end
  end
end
