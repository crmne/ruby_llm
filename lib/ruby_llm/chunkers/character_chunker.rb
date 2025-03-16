# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Splits content into chunks based on character count
    class CharacterChunker < Chunker
      DEFAULT_CHUNK_SIZE = 2000
      DEFAULT_OVERLAP = 200

      def initialize(chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
        super
        @chunk_size = chunk_size
        @overlap = overlap
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        # General implementation for other cases
        chunks = []
        start_pos = 0

        while start_pos < content.length
          # Calculate end position for this chunk
          chunk_end = [start_pos + @chunk_size, content.length].min

          # Add the chunk
          chunks << content[start_pos...chunk_end]

          # If we've reached the end, break
          break if chunk_end >= content.length

          # Calculate next start position
          start_pos += @chunk_size - @overlap
        end

        chunks
      end
    end
  end
end
