# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Splits content into chunks based on paragraphs
    class ParagraphChunker < Chunker
      DEFAULT_MIN_SIZE = 100
      DEFAULT_MAX_SIZE = 2000
      DEFAULT_SEPARATOR = "\n\n"

      def initialize(min_size: DEFAULT_MIN_SIZE,
                     max_size: DEFAULT_MAX_SIZE,
                     separator: DEFAULT_SEPARATOR)
        super()
        @min_size = min_size
        @max_size = max_size
        @separator = separator
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        paragraphs = content.split(@separator).reject(&:empty?)
        chunks = []
        current_chunk = ''

        paragraphs.each do |paragraph|
          # If the paragraph alone exceeds max_size, we need to handle it separately
          if paragraph.length > @max_size
            # Add the current chunk if it's not empty
            chunks << current_chunk.strip unless current_chunk.empty?

            # Split the large paragraph (this is a simple approach - you might want to improve it)
            split_paragraph(paragraph).each do |split|
              chunks << split.strip
            end

            current_chunk = ''
          elsif current_chunk.empty?
            current_chunk = paragraph
          elsif (current_chunk.length + @separator.length + paragraph.length) <= @max_size
            current_chunk += @separator + paragraph
          else
            chunks << current_chunk.strip
            current_chunk = paragraph
          end
        end
        chunks << current_chunk.strip unless current_chunk.empty?

        # Merge small chunks if necessary, while still respecting max_size
        merge_small_chunks(chunks)
      end

      private

      # Split a paragraph that's larger than max_size into smaller chunks
      def split_paragraph(paragraph)
        result = []
        # Simple approach: just split by max_size characters
        # A more sophisticated approach might split by sentences
        i = 0
        while i < paragraph.length
          result << paragraph[i, @max_size]
          i += @max_size
        end
        result
      end

      # Merge small chunks while respecting max_size
      def merge_small_chunks(chunks)
        return chunks if chunks.empty?

        merged_chunks = []
        buffer = ''

        chunks.each do |chunk|
          if buffer.empty?
            buffer = chunk
          elsif (buffer.length + @separator.length + chunk.length) <= @max_size
            buffer += @separator + chunk
          else
            merged_chunks << buffer.strip
            buffer = chunk
          end
        end
        merged_chunks << buffer.strip unless buffer.empty?

        merged_chunks
      end
    end
  end
end
