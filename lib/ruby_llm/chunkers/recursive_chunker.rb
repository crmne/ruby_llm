# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Recursively splits content into chunks using a hierarchical approach
    class RecursiveChunker < Chunker
      DEFAULT_MIN_SIZE = 100
      DEFAULT_MAX_SIZE = 2000
      DEFAULT_SEPARATOR_PATTERNS = [
        /\n{3,}/,            # Multiple blank lines
        /[.!?]\s+/,          # Sentence boundaries
        /[,;]\s+/,           # Clause boundaries
        /\s+/                # Word boundaries
      ].freeze

      def initialize(min_size: DEFAULT_MIN_SIZE,
                     max_size: DEFAULT_MAX_SIZE,
                     separator_patterns: DEFAULT_SEPARATOR_PATTERNS)
        super
        @min_size = min_size
        @max_size = max_size
        @separator_patterns = separator_patterns
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        chunks = recursive_split(content)
        combine_small_chunks(chunks)
      end

      private

      def recursive_split(text, depth = 0)
        return [text] if text.length <= @max_size || depth >= @separator_patterns.length

        separator = @separator_patterns[depth]
        chunks = split_with_pattern(text, separator)

        # If splitting didn't help, try next pattern
        return recursive_split(text, depth + 1) if chunks.length == 1 && chunks.first == text

        # For sentence boundaries specifically, ensure we're actually splitting
        if depth == 1 && chunks.length == 1 && text.length > @max_size
          # Force split at sentence boundaries
          forced_chunks = text.split(/(?<=[.!?])\s+/)
          if forced_chunks.length > 1
            return forced_chunks.flat_map do |chunk|
              chunk.length > @max_size ? recursive_split(chunk, depth + 1) : [chunk]
            end
          end
        end

        # Recursively process chunks that are still too large
        chunks.flat_map do |chunk|
          if chunk.length > @max_size
            recursive_split(chunk, depth + 1)
          else
            [chunk]
          end
        end
      end

      def split_with_pattern(text, pattern)
        # Keep the separator with the split parts for better chunking
        parts = []
        last_index = 0

        text.scan(pattern) do |_|
          match = Regexp.last_match
          part = text[last_index...match.end(0)]
          parts << part unless part.empty?
          last_index = match.end(0)
        end

        # Add the remaining text if any
        parts << text[last_index..] if last_index < text.length

        # If no splits were found, return the original text
        return [text] if parts.empty?

        # Recombine parts that would be too small
        result = []
        current_chunk = ''

        parts.each do |part|
          if current_chunk.length + part.length > @max_size && !current_chunk.empty?
            result << current_chunk
            current_chunk = ''
          end

          current_chunk += part
        end

        result << current_chunk unless current_chunk.empty?
        result
      end

      def combine_small_chunks(chunks)
        return chunks if chunks.length <= 1

        result = []
        current_chunk = chunks.first

        chunks[1..].each do |chunk|
          combined_size = current_chunk.length + chunk.length + 1

          if combined_size <= @max_size && (current_chunk.length < @min_size || chunk.length < @min_size)
            current_chunk = [current_chunk, chunk].join(' ')
          else
            result << current_chunk
            current_chunk = chunk
          end
        end

        # Process the last chunk
        result << current_chunk

        # Make another pass to ensure all chunks meet minimum size
        final_result = []
        current = nil

        result.each do |chunk|
          if current.nil?
            current = chunk
          elsif current.length < @min_size && (current.length + chunk.length + 1) <= @max_size
            current = [current, chunk].join(' ')
          else
            final_result << current
            current = chunk
          end
        end

        final_result << current unless current.nil?
        final_result
      end
    end
  end
end
