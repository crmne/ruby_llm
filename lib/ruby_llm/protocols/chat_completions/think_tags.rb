# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Splits a <think>...</think> block that opens the content into
      # thinking. Model output is untrusted: each byte is scanned once,
      # without regular expressions, and only a partial tag and a little
      # leading whitespace are ever held back.
      class ThinkTags # :nodoc:
        OPEN = '<think>'
        CLOSE = '</think>'
        MAX_LEADING_WHITESPACE = 64
        WHITESPACE = [9, 10, 11, 12, 13, 32].freeze

        def self.split(text)
          splitter = new
          content, thinking = splitter.feed(text)
          rest_content, rest_thinking = splitter.finish
          [join(content, rest_content), join(thinking, rest_thinking), splitter.offset]
        end

        def self.join(first, second)
          return second if first.nil? || first.empty?
          return first if second.nil? || second.empty?

          first + second
        end

        def initialize
          @state = :start
          @held = +''
          @seen = 0
        end

        def offset
          @offset || (@state == :start ? 0 : @seen)
        end

        def feed(text, explicit_thinking = nil)
          return stop(text, explicit_thinking) if explicit_thinking
          return [text, nil] if text.nil? || text.empty? || @state == :off

          @seen += text.length
          case @state
          when :start then feed_start(text)
          when :thinking then feed_thinking(text)
          else feed_answer(text)
          end
        end

        def finish
          stop(nil, nil)
        end

        private

        def stop(text, thinking)
          held = take_held
          state = @state
          @offset ||= offset
          @state = :off
          return [presence(self.class.join(held, text)), thinking] if state == :start

          [text, presence(self.class.join(held, thinking))]
        end

        def feed_start(text)
          buffer = with_held(text)
          leading = whitespace_length(buffer, MAX_LEADING_WHITESPACE + 1)
          if leading <= MAX_LEADING_WHITESPACE
            body = buffer.byteslice(leading..)
            return open_block(body) if body.start_with?(OPEN)
            return hold(buffer) if OPEN.start_with?(body)
          end

          @state = :off
          @offset = 0
          [buffer, nil]
        end

        def open_block(body)
          @state = :thinking
          feed_thinking(body.byteslice(OPEN.bytesize..))
        end

        def feed_thinking(text)
          buffer = with_held(text)
          close = buffer.byteindex(CLOSE)
          return close_block(buffer, close) if close

          kept = partial_close_length(buffer)
          @held = buffer.byteslice(buffer.bytesize - kept, kept)
          [nil, presence(buffer.byteslice(0, buffer.bytesize - kept))]
        end

        def close_block(buffer, close)
          @state = :answer
          content, = feed_answer(buffer.byteslice((close + CLOSE.bytesize)..))
          [content, presence(buffer.byteslice(0, close))]
        end

        def feed_answer(text)
          leading = whitespace_length(text, text.bytesize)
          return [nil, nil] if leading == text.bytesize

          answer = text.byteslice(leading..)
          @state = :off
          @offset = @seen - answer.length
          [answer, nil]
        end

        def whitespace_length(text, limit)
          length = 0
          length += 1 while length < limit && WHITESPACE.include?(text.getbyte(length))
          length
        end

        def partial_close_length(buffer)
          (CLOSE.bytesize - 1).downto(1).find { |length| buffer.end_with?(CLOSE.byteslice(0, length)) } || 0
        end

        def hold(buffer)
          @held = buffer
          [nil, nil]
        end

        def with_held(text)
          return text if @held.empty?

          take_held + text
        end

        def take_held
          held = @held
          @held = +''
          held
        end

        def presence(text)
          return if text.nil? || text.empty?

          text
        end
      end
    end
  end
end
