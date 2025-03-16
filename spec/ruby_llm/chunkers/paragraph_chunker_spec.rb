# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::ParagraphChunker do
  let(:chunker) { described_class.new(min_size: 10, max_size: 50) }

  describe '#chunk' do
    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'splits content into paragraphs' do
      content = [
        'Fir par.',
        '',
        'Second paragraph that is a bit longer.',
        '',
        'Third paragraph.'
      ].join("\n\n")

      chunks = chunker.chunk(content)

      expect(chunks).to eq([
                             "Fir par.\n\nSecond paragraph that is a bit longer.",
                             'Third paragraph.'
                           ])
    end

    it 'combines small paragraphs' do
      content = [
        'Small one.',
        '',
        'Also small.',
        '',
        'Third small.',
        '',
        'A much longer paragraph that should be in its own.'
      ].join("\n\n")

      chunks = chunker.chunk(content)

      expect(chunks).to eq([
                             "Small one.\n\nAlso small.\n\nThird small.",
                             'A much longer paragraph that should be in its own.'
                           ])
    end

    it 'handles single-paragraph content' do
      content = 'Just one paragraph here.'
      expect(chunker.chunk(content)).to eq(['Just one paragraph here.'])
    end

    it 'respects max_size parameter' do
      chunker = described_class.new(max_size: 20)
      content = [
        'This is a longer first paragraph.',
        '',
        'This is another longer paragraph.',
        '',
        'Short one.'
      ].join("\n\n")

      chunks = chunker.chunk(content)
      chunks.each do |chunk|
        expect(chunk.length).to be <= 20
      end
    end

    it 'handles custom separator' do
      chunker = described_class.new(min_size: 10, max_size: 50, separator: "\n---\n")
      content = [
        'First paragraph',
        '---',
        'Second paragraph',
        '---',
        'Third paragraph'
      ].join("\n")

      expect(chunker.chunk(content)).to eq([
                                             "First paragraph\n---\nSecond paragraph",
                                             'Third paragraph'
                                           ])
    end
  end
end
