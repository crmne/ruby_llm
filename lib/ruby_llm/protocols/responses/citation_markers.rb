# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Removes the citation markers OpenAI's models write into their text:
      # U+E200, then "cite" and the turns it cites, each after a U+E202,
      # then U+E201. Only OpenAI's own tools turn them into annotations, so
      # a model that writes them without those tools leaves them in the
      # answer. Model output is untrusted: each character is read once, and
      # an unclosed marker holds back at most MAX_LENGTH characters. #shift
      # maps an index into the text as sent onto the text without markers.
      class CitationMarkers # :nodoc:
        OPEN = "\u{E200}"
        CLOSE = "\u{E201}"
        SEPARATOR = "\u{E202}"
        MARKS = [OPEN, CLOSE, SEPARATOR].freeze
        CITE = 'cite'
        TURN = 'turn'
        MAX_LENGTH = 256

        def self.strip(text)
          markers = new
          ["#{markers.feed(text)}#{markers.finish}", markers]
        end

        def initialize
          @held = nil
          @seen = 0
          @removed = []
        end

        def feed(text)
          return text if text.nil? || text.empty?

          output = +''
          text.each_char { |char| read(char, output) }
          output.empty? ? nil : output
        end

        def finish
          return unless @held

          held = @held
          @held = nil
          return drop(held) if citation_prefix?(held)

          output = +''
          release(held, output)
          output
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
            output << char
          end
          @seen += 1
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
          marker?(held) && held.split(SEPARATOR, -1).drop(1).all? { |turn| turn.start_with?(TURN) }
        end

        def marker?(held)
          word, *turns = held.delete_prefix(OPEN).split(SEPARATOR, -1)
          return false unless word.to_s.end_with?(CITE) && word.each_char.all? { |char| alphanumeric?(char) }

          turns.all? { |turn| turn?(turn) }
        end

        def turn?(reference)
          return false unless reference.start_with?(TURN) || TURN.start_with?(reference)

          reference.each_char.all? { |char| alphanumeric?(char) }
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
          nil
        end

        def release(held, output)
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
