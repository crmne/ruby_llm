# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Removes the citation markers OpenAI's models write into their text:
      # U+E200, then "cite" and the sources and line locators it cites, each
      # after a U+E202, then U+E201. Only OpenAI's own tools turn them into annotations, so
      # a model that writes them without those tools leaves them in the
      # answer. Model output is untrusted: each character is read once, and
      # an unclosed marker holds back at most MAX_LENGTH characters. A space
      # before a removed marker goes too when punctuation, a space, or the end
      # of the text follows. Only a marker holds a space past the end of a
      # stream chunk, so text keeps its order across content parts. #shift
      # maps an index into the text as sent onto the text without markers.
      class CitationMarkers # :nodoc:
        OPEN = "\u{E200}"
        CLOSE = "\u{E201}"
        SEPARATOR = "\u{E202}"
        MARKS = [OPEN, CLOSE, SEPARATOR].freeze
        CITE = 'cite'
        REFERENCE = /\A[\w-]*\z/
        SPACE = ' '
        BOUNDARY = /[[:space:].,;:!?)\]}]/
        MAX_LENGTH = 256

        def self.strip(text)
          markers = new
          ["#{markers.feed(text)}#{markers.finish}", markers]
        end

        def initialize
          @held = nil
          @seen = 0
          @removed = []
          @space_at = nil
          @after_marker = false
        end

        def feed(text)
          return text if text.nil? || text.empty?

          output = +''
          text.each_char { |char| read(char, output) }
          settle_space(output, boundary: false) unless @held || @after_marker
          output.empty? ? nil : output
        end

        def finish
          output = +''
          held = take_held
          if held && !citation_prefix?(held)
            release(held, output)
          else
            drop(held) if held
            settle_space(output, boundary: true)
          end
          output.empty? ? nil : output
        end

        def shift(index)
          return index if index.nil?

          index - @removed.sum { |position, length| position < index ? length : 0 }
        end

        private

        def read(char, output)
          if @held
            hold(char, output)
          elsif char == OPEN
            open_marker
          elsif MARKS.include?(char)
            @removed << [@seen, 1]
          else
            write(char, output)
          end
          @seen += 1
        end

        def write(char, output)
          settle_space(output, boundary: char.match?(BOUNDARY))
          if char == SPACE
            @space_at = @seen
          else
            output << char
          end
        end

        def settle_space(output, boundary:)
          if @space_at && @after_marker && boundary
            @removed << [@space_at, 1]
          elsif @space_at
            output << SPACE
          end
          @space_at = nil
          @after_marker = false
        end

        def open_marker
          @held = +OPEN
          @held_at = @seen
        end

        def hold(char, output)
          if char == OPEN
            release(@held, output)
            open_marker
          else
            @held << char
            return close_marker(output) if char == CLOSE

            release(take_held, output) if @held.length > MAX_LENGTH
          end
        end

        def close_marker(output)
          held = take_held
          complete_marker?(held.delete_suffix(CLOSE)) ? drop(held) : release(held, output)
        end

        def citation_prefix?(held)
          CITE.start_with?(held.delete_prefix(OPEN)) || marker?(held)
        end

        def complete_marker?(held)
          marker?(held) && held.split(SEPARATOR, -1).drop(1).none?(&:empty?)
        end

        def marker?(held)
          word, *references = held.delete_prefix(OPEN).split(SEPARATOR, -1)
          return false unless word.to_s.end_with?(CITE) && word.each_char.all? { |char| alphanumeric?(char) }

          references.all? { |reference| reference.match?(REFERENCE) }
        end

        def alphanumeric?(char)
          char.match?(/[[:alnum:]]/)
        end

        def take_held
          held = @held
          @held = nil
          held
        end

        def drop(held)
          @removed << [@held_at, held.length]
          @after_marker = true
          nil
        end

        def release(held, output)
          settle_space(output, boundary: false)
          held.each_char.with_index do |char, index|
            if MARKS.include?(char)
              @removed << [@held_at + index, 1]
            else
              output << char
            end
          end
        end
      end
    end
  end
end
