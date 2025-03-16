# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::SemanticChunker do
  let(:chunker) { described_class.new(min_size: 20, max_size: 100) }

  before do
    allow(RubyLLM).to receive(:embed)
  end

  describe '#chunk' do
    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'returns original content for single sentence' do
      content = 'This is a single sentence.'
      expect(chunker.chunk(content)).to eq([content])
    end

    it 'groups semantically similar sentences together' do
      # Using a different formatting to ensure sentence splitting works correctly
      content = 'Machine learning is a fascinating field. AI systems can learn from data. ' +
                'The weather is nice today. The sun is shining brightly. ' +
                'Neural networks process information. Deep learning models use layers.'

      # Use vectors with absolutely zero similarity between topics
      # but perfect similarity within topics
      ml_embedding = [1.0, 0.0, 0.0]        # Topic 1 direction
      weather_embedding = [0.0, 1.0, 0.0]   # Topic 2 direction (orthogonal to Topic 1)
      neural_embedding = [0.0, 0.0, 1.0]    # Topic 3 direction (orthogonal to both)

      # Set up the mocks in strict sequence
      allow(RubyLLM).to receive(:embed).and_return(
        double(vectors: [ml_embedding]),      # First sentence
        double(vectors: [ml_embedding]),      # Second sentence
        double(vectors: [weather_embedding]), # Third sentence
        double(vectors: [weather_embedding]), # Fourth sentence
        double(vectors: [neural_embedding]),  # Fifth sentence
        double(vectors: [neural_embedding])   # Sixth sentence
      )

      chunks = chunker.chunk(content)

      expect(chunks.length).to eq(3)
      expect(chunks[0]).to include('Machine learning')
      expect(chunks[1]).to include('weather')
      expect(chunks[2]).to include('Neural networks')
    end

    it 'respects max_size parameter' do
      chunker = described_class.new(max_size: 30)
      content = 'First sentence. Second sentence. Third sentence. Fourth sentence.'

      # Mock similar embeddings
      embedding = [0.1, 0.2, 0.3]
      allow(RubyLLM).to receive(:embed).and_return(
        double(vectors: [embedding]),
        double(vectors: [embedding]),
        double(vectors: [embedding]),
        double(vectors: [embedding])
      )

      chunks = chunker.chunk(content)
      chunks.each do |chunk|
        expect(chunk.length).to be <= 30
      end
    end

    it 'combines small chunks when possible' do
      content = <<~TEXT
        Short one. Also short.
        Another brief text. Final short one.
      TEXT

      # Mock similar embeddings
      embedding = [0.1, 0.2, 0.3]
      allow(RubyLLM).to receive(:embed).and_return(
        double(vectors: [embedding]),
        double(vectors: [embedding]),
        double(vectors: [embedding]),
        double(vectors: [embedding])
      )

      chunks = chunker.chunk(content)
      expect(chunks.length).to be < content.split('.').length - 1
    end

    it 'handles custom similarity threshold' do
      # Create a chunker with high similarity threshold
      chunker = described_class.new(similarity_threshold: 0.95, min_size: 0)

      # Setup test content
      content = 'First topic. Similar first. New topic. Related to new.'

      # Define test sentences - these are what split_into_sentences should return
      test_sentences = ['First topic', 'Similar first', 'New topic', 'Related to new']

      # Define test embeddings with specific similarity relationships:
      # - Similar sentences have 0.9 similarity (below threshold)
      first_topic = [1.0, 0.0, 0.0]
      similar_first = [0.9, 0.435889, 0.0]  # 0.9 similarity with first_topic
      new_topic = [0.0, 1.0, 0.0]           # No similarity with first_topic
      similar_new = [0.0, 0.9, 0.435889]    # 0.9 similarity with new_topic

      # Mock the necessary methods for controlled testing
      allow_any_instance_of(described_class).to receive(:split_into_sentences).and_return(test_sentences)
      allow_any_instance_of(described_class).to receive(:get_embeddings).and_return([
                                                                                      first_topic, similar_first, new_topic, similar_new
                                                                                    ])

      # Test that the chunker creates 4 separate chunks with these settings
      chunks = chunker.chunk(content)
      expect(chunks.length).to eq(4)
    end
  end
end
