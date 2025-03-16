# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Splits content into semantically coherent chunks using sentence embeddings
    class SemanticChunker < Chunker
      DEFAULT_MIN_SIZE = 100
      DEFAULT_MAX_SIZE = 2000
      DEFAULT_SIMILARITY_THRESHOLD = 0.7
      DEFAULT_MODEL = 'gpt-3.5-turbo'
      SENTENCE_END = /[.!?](?=\s+[A-Z]|$)/

      def initialize(min_size: DEFAULT_MIN_SIZE,
                     max_size: DEFAULT_MAX_SIZE,
                     similarity_threshold: DEFAULT_SIMILARITY_THRESHOLD,
                     model: DEFAULT_MODEL)
        super
        @min_size = min_size
        @max_size = max_size
        @similarity_threshold = similarity_threshold
        @model = model
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        # Split into sentences
        sentences = split_into_sentences(content)
        return [content] if sentences.length <= 1

        # Get embeddings for each sentence
        embeddings = get_embeddings(sentences)

        # Group sentences into semantic chunks
        chunks = create_semantic_chunks(sentences, embeddings)

        # Important: Skip combination if min_size is 0
        return chunks if @min_size == 0

        # Otherwise combine small chunks and ensure max size
        combine_chunks(chunks)
      end

      private

      def split_into_sentences(text)
        sentences = []
        current_pos = 0

        while match = text[current_pos..].match(SENTENCE_END)
          end_pos = current_pos + match.begin(0) + 1
          sentence = text[current_pos...end_pos].strip
          sentences << sentence unless sentence.empty?
          current_pos = end_pos
        end

        # Add remaining text as last sentence if not empty
        remaining = text[current_pos..].strip
        sentences << remaining unless remaining.empty?
        sentences
      end

      def get_embeddings(sentences)
        sentences.map do |sentence|
          # Get embedding for each sentence
          response = RubyLLM.embed(sentence, model: @model)
          vector = response.vectors.first
          # Handle both flat and nested vector formats
          vector.is_a?(Array) && vector.first.is_a?(Array) ? vector.first : vector
        end
      end

      def cosine_similarity(vec1, vec2)
        dot_product = vec1.zip(vec2).sum { |a, b| a * b }
        magnitude1 = Math.sqrt(vec1.sum { |x| x * x })
        magnitude2 = Math.sqrt(vec2.sum { |x| x * x })

        # Avoid division by zero
        return 0.0 if magnitude1.zero? || magnitude2.zero?

        # Ensure similarity is between 0 and 1
        dot_product / (magnitude1 * magnitude2)
      end

      def create_semantic_chunks(sentences, embeddings)
        return [sentences.join(' ')] if sentences.length <= 1

        chunks = []
        current_chunk = [sentences.first]
        current_reference = embeddings.first # Keep reference to first embedding in chunk

        sentences.zip(embeddings)[1..].each do |sentence, embedding|
          # Compare with reference embedding (first sentence in current chunk)
          similarity = cosine_similarity(current_reference, embedding)

          # Important: Use exact threshold comparison
          if similarity >= @similarity_threshold &&
             (current_chunk.join(' ').length + sentence.length + 1) <= @max_size
            # Add to current chunk if similar enough
            current_chunk << sentence
          else
            # Start a new chunk
            chunks << current_chunk.join(' ')
            current_chunk = [sentence]
            current_reference = embedding # Update reference for new chunk
          end
        end

        # Add the last chunk
        chunks << current_chunk.join(' ') unless current_chunk.empty?

        chunks
      end

      def average_embeddings(embeddings)
        # Calculate element-wise average of embeddings
        size = embeddings.first.size
        sums = Array.new(size, 0.0)

        embeddings.each do |embedding|
          embedding.each_with_index do |value, i|
            sums[i] += value
          end
        end

        sums.map { |sum| sum / embeddings.length }
      end

      def combine_chunks(chunks)
        return chunks if chunks.length <= 1 || @min_size == 0

        result = []
        current_chunk = chunks.first

        chunks[1..].each do |chunk|
          combined_size = current_chunk.length + chunk.length + 1

          if combined_size <= @max_size &&
             current_chunk.length < @min_size &&
             chunk.length < @min_size
            # Only combine if both chunks are smaller than min_size
            current_chunk = [current_chunk, chunk].join(' ')
          else
            result << current_chunk
            current_chunk = chunk
          end
        end

        result << current_chunk
        result
      end
    end
  end
end
