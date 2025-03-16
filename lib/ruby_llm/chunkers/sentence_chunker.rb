# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Splits content into chunks based on sentence boundaries
    class SentenceChunker < Chunker
      DEFAULT_MIN_SIZE = 100
      DEFAULT_MAX_SIZE = 2000

      # Common abbreviations to avoid false sentence breaks
      ABBREVIATIONS = [
        'Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.',
        'Sr.', 'Jr.', 'Ltd.', 'Inc.', 'Co.',
        'i.e.', 'e.g.', 'etc.', 'vs.', 'fig.',
        'U.S.', 'U.K.', 'A.M.', 'P.M.'
      ].freeze

      # Simple sentence end pattern
      SENTENCE_END_PATTERN = /[.!?](?=\s+|$)/

      def initialize(min_size: DEFAULT_MIN_SIZE, max_size: DEFAULT_MAX_SIZE)
        super
        @min_size = min_size
        @max_size = max_size
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        # Extract sentences considering abbreviations
        sentences = extract_sentences_with_abbreviations(content)

        # Combine sentences intelligently
        chunks = intelligently_combine_sentences(sentences)

        # Make sure no chunk exceeds max_size
        ensure_max_size_respected(chunks)
      end

      private

      def extract_sentences_with_abbreviations(text)
        # First, replace all known abbreviations with placeholders
        temp_text = text.dup
        abbr_map = {}

        ABBREVIATIONS.each_with_index do |abbr, idx|
          placeholder = "ABBR_PLACEHOLDER_#{idx}_"
          temp_text.gsub!(/#{Regexp.escape(abbr)}(?=\s|$)/) do |_match|
            pos = Regexp.last_match.offset(0)[0]
            abbr_map[pos] = abbr
            placeholder
          end
        end

        # Now split by sentence endings
        potential_sentences = []
        start_idx = 0

        temp_text.scan(SENTENCE_END_PATTERN) do |_match|
          match_pos = Regexp.last_match.offset(0)[0]
          sentence = temp_text[start_idx..match_pos]
          potential_sentences << sentence unless sentence.strip.empty?
          start_idx = match_pos + 1
        end

        # Add the last part if it exists and doesn't end with a sentence marker
        potential_sentences << temp_text[start_idx..] if start_idx < temp_text.length

        # Restore abbreviations
        final_sentences = []

        potential_sentences.each do |sentence|
          restored = sentence.dup

          ABBREVIATIONS.each_with_index do |abbr, idx|
            marker = "ABBR_PLACEHOLDER_#{idx}_"
            restored.gsub!(marker, abbr)
          end

          final_sentences << restored.strip
        end

        # Merge sentences that were split on abbreviations
        consolidate_abbreviation_sentences(final_sentences)
      end

      def consolidate_abbreviation_sentences(sentences)
        return sentences if sentences.empty?

        result = []
        i = 0

        while i < sentences.length
          current = sentences[i]

          # Check if current sentence ends with an abbreviation
          ends_with_abbr = ABBREVIATIONS.any? { |abbr| current.end_with?(abbr) }

          # If it ends with an abbreviation and there's a next sentence, join them
          if ends_with_abbr && (i + 1 < sentences.length)
            result << "#{current} #{sentences[i + 1]}"
            i += 2
          else
            result << current
            i += 1
          end
        end

        # If we made changes, process again to handle consecutive abbreviations
        return consolidate_abbreviation_sentences(result) if result.length < sentences.length

        result
      end

      def intelligently_combine_sentences(sentences)
        return [] if sentences.empty?

        chunks = []
        current_chunk = []
        current_size = 0

        sentences.each do |sentence|
          sentence_size = sentence.length

          # If current chunk exists and adding this sentence would exceed max_size
          # OR if adding would create a chunk with more than 2 sentences (for short sentences)
          if !current_chunk.empty? &&
             (current_size + sentence_size + 1 > @max_size ||
              (current_size < @min_size && current_chunk.length >= 2))
            chunks << current_chunk.join(' ')
            current_chunk = []
            current_size = 0
          end

          # Add sentence to the current chunk
          current_chunk << sentence
          current_size += sentence_size + (current_chunk.size > 1 ? 1 : 0) # +1 for space
        end

        # Add the final chunk
        chunks << current_chunk.join(' ') unless current_chunk.empty?

        # Try to combine small chunks while respecting max_size
        combine_small_chunks(chunks)
      end

      def combine_small_chunks(chunks)
        return chunks if chunks.length <= 1

        result = []
        i = 0

        while i < chunks.length
          current = chunks[i]

          # If current chunk is small and there's a next chunk
          if current.length < @min_size && i + 1 < chunks.length
            next_chunk = chunks[i + 1]

            # If combining wouldn't exceed max_size
            if current.length + next_chunk.length + 1 <= @max_size
              result << "#{current} #{next_chunk}"
              i += 2
            else
              result << current
              i += 1
            end
          else
            result << current
            i += 1
          end
        end

        # If we combined any chunks, try again
        return combine_small_chunks(result) if result.length < chunks.length

        result
      end

      def ensure_max_size_respected(chunks)
        result = []

        chunks.each do |chunk|
          if chunk.length <= @max_size
            result << chunk
          else
            # Split this chunk into smaller pieces
            result.concat(split_chunk_by_max_size(chunk))
          end
        end

        result
      end

      def split_chunk_by_max_size(chunk)
        result = []
        words = chunk.split
        current = ''

        words.each do |word|
          # If adding this word would exceed max_size
          if current.length + word.length + (current.empty? ? 0 : 1) > @max_size
            result << current unless current.empty?

            # If single word is too long, split it
            if word.length > @max_size
              start = 0
              while start < word.length
                end_pos = [start + @max_size, word.length].min
                result << word[start...end_pos]
                start = end_pos
              end
              current = ''
            else
              current = word
            end
          else
            current = current.empty? ? word : "#{current} #{word}"
          end
        end

        result << current unless current.empty?
        result
      end
    end
  end
end
