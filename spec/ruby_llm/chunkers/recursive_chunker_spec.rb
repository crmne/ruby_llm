# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::RecursiveChunker do
  let(:chunker) { described_class.new(min_size: 20, max_size: 100) }

  describe '#chunk' do
    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'handles content smaller than max_size' do
      content = 'Small piece of text'
      expect(chunker.chunk(content)).to eq([content])
    end

    it 'splits content at paragraph boundaries first' do
      content = <<~TEXT
        First paragraph with some content.
        Still first paragraph.

        Second paragraph with different content.
        Still second paragraph.

        Third paragraph here.
      TEXT

      chunks = chunker.chunk(content)
      expect(chunks.length).to be >= 2
      expect(chunks.first).to include('First paragraph')
      expect(chunks).to all(have_attributes(length: be <= 100))
    end

    it 'splits at sentence boundaries when paragraphs are too large' do
      # Make sure this content is long enough to force splitting
      content = 'First very long sentence that exceeds the limit and needs to be split into multiple chunks. ' \
                'Second sentence here with additional text to ensure we go over the max size. ' \
                'Third sentence for testing with more words to increase length.'

      chunks = chunker.chunk(content)
      expect(chunks.length).to be >= 2
      expect(chunks).to all(have_attributes(length: be <= 100))
      chunks.each do |chunk|
        expect(chunk).to match(/[.!?]\s*$/) # Each chunk should end with sentence boundary
      end
    end

    it 'splits at clause boundaries when sentences are too large' do
      content = 'This is a very long sentence with multiple clauses, ' \
                'including this middle clause, ' \
                'and finally ending with this clause.'

      chunks = chunker.chunk(content)
      expect(chunks).to all(have_attributes(length: be <= 100))
    end

    it 'splits at word boundaries as last resort' do
      content = 'ThisIsAVeryLongStringWithoutAnySeparatorsOrPunctuationThatNeedsToBeChunked'

      chunks = chunker.chunk(content)
      expect(chunks).to all(have_attributes(length: be <= 100))
    end

    it 'combines small chunks' do
      content = 'Small chunk. ' * 10
      chunks = chunker.chunk(content)

      expect(chunks).to all(have_attributes(length: be >= 20))
      expect(chunks).to all(have_attributes(length: be <= 100))
    end

    context 'with custom separator patterns' do
      let(:custom_patterns) { [/\n/, /\./, /\s+/] }
      let(:chunker) do
        described_class.new(
          min_size: 20,
          max_size: 100,
          separator_patterns: custom_patterns
        )
      end

      it 'respects custom separator patterns' do
        content = "Line1\nLine2\nLine3. Sentence2. Words words words."
        chunks = chunker.chunk(content)

        expect(chunks).to all(have_attributes(length: be <= 100))
        expect(chunks.first).to match(/^Line/)
      end
    end
  end
end
