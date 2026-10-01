# frozen_string_literal: true

module RubyLLM
  module Transport
    # Interprets a text/event-stream as the HTML standard describes, fed in
    # whatever pieces the network delivers. Each dispatched event is yielded
    # as its type, data, and last event ID. The last event ID and the
    # reconnection time the server asked for stay readable between events.
    class EventStreamParser # :nodoc:
      BOM = "\xEF\xBB\xBF".b.freeze
      LINE_BREAK = /[\r\n]/
      DIGITS = /\A[0-9]+\z/
      CR = 13
      LF = 10
      SPACE = 32

      attr_reader :last_event_id, :reconnection_time

      def initialize
        @buffer = String.new(encoding: Encoding::BINARY)
        @position = 0
        @searched = 0
        @data = +''
        @event_type = +''
        @id_buffer = +''
        @last_event_id = +''
        @reconnection_time = nil
        @started = false
        @after_cr = false
      end

      def feed(chunk, &)
        compact
        @buffer << (chunk.encoding == Encoding::BINARY ? chunk : chunk.b)
        return unless start

        skip_line_feed_after_carriage_return
        while (index = @buffer.index(LINE_BREAK, @searched))
          line = @buffer.byteslice(@position, index - @position)
          @position = @searched = line_end(index)
          process_line(line, &)
        end
        @searched = @buffer.bytesize
      end

      private

      def compact
        return if @position.zero?

        @buffer = @buffer.byteslice(@position, @buffer.bytesize - @position)
        @searched -= @position
        @position = 0
      end

      # The stream decodes as UTF-8, which drops one byte order mark at its
      # very start, so the first bytes wait until they can be told apart.
      def start
        return true if @started
        return false if @buffer.bytesize < BOM.bytesize && BOM.start_with?(@buffer)

        @position = @searched = BOM.bytesize if @buffer.start_with?(BOM)
        @started = true
      end

      # A carriage return that ended the previous piece may be the first
      # half of a CRLF pair.
      def skip_line_feed_after_carriage_return
        return unless @after_cr && @buffer.bytesize > @position

        @after_cr = false
        @position = @searched = @position + 1 if @buffer.getbyte(@position) == LF
      end

      def line_end(index)
        return index + 1 unless @buffer.getbyte(index) == CR
        return index + 2 if @buffer.getbyte(index + 1) == LF

        @after_cr = index + 1 == @buffer.bytesize
        index + 1
      end

      def process_line(line, &)
        return dispatch(&) if line.empty?
        return if line.start_with?(':')

        colon = line.index(':')
        return process_field(line, +'') unless colon

        offset = line.getbyte(colon + 1) == SPACE ? colon + 2 : colon + 1
        process_field(line.byteslice(0, colon), line.byteslice(offset, line.bytesize - offset))
      end

      def process_field(field, value)
        case field
        when 'event' then @event_type = decode(value)
        when 'data' then @data << decode(value) << "\n"
        when 'id' then @id_buffer = decode(value) unless value.include?("\0")
        when 'retry' then @reconnection_time = value.to_i if value.match?(DIGITS)
        end
      end

      def dispatch
        @last_event_id = @id_buffer
        data = @data
        type = @event_type
        @data = +''
        @event_type = +''
        return if data.empty?

        data.delete_suffix!("\n")
        yield type.empty? ? 'message' : type, data, @last_event_id
      end

      def decode(bytes)
        text = bytes.force_encoding(Encoding::UTF_8)
        text.valid_encoding? ? text : text.scrub
      end
    end
  end
end
