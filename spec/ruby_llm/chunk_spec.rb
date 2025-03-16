# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  let(:sample_text) do
    <<~TEXT
      # First Section
      This is a paragraph about machine learning.
      It contains multiple sentences about AI.

      ## Second Section
      Another paragraph with different content.
      This discusses natural language processing.

      ### Subsection
      Final paragraph with some technical details.
      It includes specific implementation notes.
    TEXT
  end

  describe '.chunk' do
    it 'raises error for unknown chunker type' do
      expect do
        described_class.chunk(sample_text, chunker: :unknown)
      end.to raise_error(ArgumentError, 'Unknown chunker type: unknown')
    end

    context 'with character chunker' do
      it 'chunks by character count' do
        chunks = described_class.chunk(sample_text, chunker: :character, chunk_size: 50, overlap: 10)

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk.length).to be <= 50
        end
      end
    end

    context 'with paragraph chunker' do
      it 'chunks by paragraphs' do
        chunks = described_class.chunk(sample_text, chunker: :paragraph, min_size: 10, max_size: 200)

        expect(chunks).not_to be_empty
        expect(chunks.first).to include('machine learning')
        expect(chunks).to all(match(/\S+/)) # No empty chunks
      end
    end

    context 'with sentence chunker' do
      it 'chunks by sentences' do
        chunks = described_class.chunk(sample_text, chunker: :sentence, min_size: 10, max_size: 200)

        expect(chunks).not_to be_empty
        chunks.each do |chunk|
          expect(chunk).to match(/[.!?](\s|$)/) # Each chunk ends with sentence terminator
        end
      end
    end

    context 'with markdown chunker' do
      it 'chunks by markdown sections' do
        chunks = described_class.chunk(sample_text, chunker: :markdown, min_size: 10, max_size: 200)

        expect(chunks).not_to be_empty
        expect(chunks.first).to include('_Context:')
        expect(chunks).to all(include('First Section')) # Context preservation
      end
    end

    context 'with semantic chunker' do
      before do
        # Mock RubyLLM.embed to return fake embeddings
        allow(RubyLLM).to receive(:embed).and_return(
          instance_double(RubyLLM::Embedding, vectors: [[0.1, 0.2, 0.3]]),
          instance_double(RubyLLM::Embedding, vectors: [[0.1, 0.2, 0.3]]),
          instance_double(RubyLLM::Embedding, vectors: [[0.7, 0.8, 0.9]]),
          instance_double(RubyLLM::Embedding, vectors: [[0.7, 0.8, 0.9]])
        )
      end

      it 'chunks by semantic similarity' do
        chunks = described_class.chunk(
          sample_text,
          chunker: :semantic,
          min_size: 20,
          max_size: 200,
          similarity_threshold: 0.7
        )

        expect(chunks).not_to be_empty
        expect(chunks.length).to be < sample_text.split("\n\n").length
      end
    end

    context 'with recursive chunker' do
      it 'chunks text recursively using different separators' do
        chunks = described_class.chunk(
          sample_text,
          chunker: :recursive,
          min_size: 20,
          max_size: 100
        )

        expect(chunks).not_to be_empty
        expect(chunks).to all(have_attributes(length: be <= 100))
        expect(chunks).to all(have_attributes(length: be >= 20))
      end

      it 'handles complex nested content' do
        content = <<~TEXT
          Introduction to the topic with a very detailed explanation that spans multiple lines and includes various punctuation marks, making it suitable for testing the recursive splitting algorithm's behavior with different separator patterns.

          First major point, which contains several sub-points:
          - Point A, elaborated in detail
          - Point B, with additional context
          - Point C, including examples

          Second major point that discusses technical implementation details, including code samples and specific requirements that need to be considered for proper functionality.
        TEXT

        chunks = described_class.chunk(
          content,
          chunker: :recursive,
          min_size: 50,
          max_size: 200
        )

        expect(chunks).not_to be_empty
        expect(chunks).to all(have_attributes(length: be <= 200))
        expect(chunks).to all(have_attributes(length: be >= 50))
        expect(chunks.first).to include('Introduction')
      end

      it 'respects custom separator patterns' do
        custom_patterns = [
          /\n{2,}/,    # Double newlines
          /[.!?]\s+/,  # Sentence endings
          /[:;]\s+/,   # Colons and semicolons
          /\s+/        # Spaces
        ]

        content = "First part: detailed explanation; more details.\n\n" \
                  "Second part: another explanation; with details.\n\n" \
                  'Third part with multiple sentences. Each one is separate. ' \
                  'Testing the splitting.'

        chunks = described_class.chunk(
          content,
          chunker: :recursive,
          separator_patterns: custom_patterns,
          min_size: 20,
          max_size: 100
        )

        expect(chunks).not_to be_empty
        expect(chunks).to all(have_attributes(length: be <= 100))
        expect(chunks).to all(have_attributes(length: be >= 20))
      end
    end

    context 'with nil or empty input' do
      it 'returns empty array for nil input' do
        expect(described_class.chunk(nil, chunker: :character)).to eq([])
        expect(described_class.chunk(nil, chunker: :paragraph)).to eq([])
        expect(described_class.chunk(nil, chunker: :sentence)).to eq([])
        expect(described_class.chunk(nil, chunker: :markdown)).to eq([])
        expect(described_class.chunk(nil, chunker: :semantic)).to eq([])
        expect(described_class.chunk(nil, chunker: :recursive)).to eq([])
      end

      it 'returns empty array for empty input' do
        expect(described_class.chunk('', chunker: :character)).to eq([])
        expect(described_class.chunk('', chunker: :paragraph)).to eq([])
        expect(described_class.chunk('', chunker: :sentence)).to eq([])
        expect(described_class.chunk('', chunker: :markdown)).to eq([])
        expect(described_class.chunk('', chunker: :semantic)).to eq([])
        expect(described_class.chunk('', chunker: :recursive)).to eq([])
      end
    end

    context 'with single chunk content' do
      let(:short_text) { 'This is a short text.' }

      it 'returns single chunk for short content' do
        chunkers = %i[character paragraph sentence markdown semantic recursive]

        chunkers.each do |chunker|
          chunks = described_class.chunk(short_text, chunker: chunker)
          expect(chunks).to eq([short_text])
        end
      end
    end
  end
end
