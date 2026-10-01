# frozen_string_literal: true

require 'spec_helper'
require 'event_stream_parser'
require 'yaml'

# The cases follow "Interpreting an event stream" in the HTML standard:
# https://html.spec.whatwg.org/multipage/server-sent-events.html#event-stream-interpretation
RSpec.describe RubyLLM::Transport::EventStreamParser do
  def parse(stream, pieces: [stream.b], parser: described_class.new)
    events = []
    pieces.each { |piece| parser.feed(piece) { |type, data, id| events << [type, data, id] } }
    events
  end

  def bytewise(stream)
    stream.b.each_char.to_a
  end

  def split_at_random(stream, random)
    bytes = stream.b
    cuts = Array.new(random.rand(1..8)) { random.rand(0..bytes.bytesize) }.sort.uniq
    ([0] + cuts).zip(cuts + [bytes.bytesize]).map { |from, to| bytes.byteslice(from, to - from) }
  end

  conformance = {
    'dispatches an event at a blank line' =>
      ["data: hello\n\n", [['message', 'hello', '']]],
    'reports the event type, defaulting to message' =>
      ["event: add\ndata: 1\n\ndata: 2\n\n", [['add', '1', ''], ['message', '2', '']]],
    'treats an empty event type as message' =>
      ["event:\ndata: 1\n\n", [['message', '1', '']]],
    'ends lines with CRLF' =>
      ["data: a\r\n\r\n", [['message', 'a', '']]],
    'ends lines with a lone CR' =>
      ["data: a\r\rdata: b\r\r", [['message', 'a', ''], ['message', 'b', '']]],
    'ends lines with any mix of CR, LF, and CRLF' =>
      ["data:test\r\ndata\ndata:test\r\n\r\n", [['message', "test\n\ntest", '']]],
    'strips one byte order mark at the start of the stream' =>
      ["\uFEFFdata:1\n\n\uFEFFdata:2\n\ndata:3\n\n", [['message', '1', ''], ['message', '3', '']]],
    'strips only the first of two byte order marks' =>
      ["\uFEFF\uFEFFdata:1\n\ndata:2\n\ndata:3\n\n", [['message', '2', ''], ['message', '3', '']]],
    'ignores comment lines' =>
      [": ping\ndata: a\n:\n\n", [['message', 'a', '']]],
    'takes a line without a colon as a field with an empty value' =>
      ["data\n\ndata\ndata\n\ndata:test\n\n", [['message', '', ''], ['message', "\n", ''], ['message', 'test', '']]],
    'strips one leading space from the value' =>
      ["data:  two\n\ndata:none\n\n", [['message', ' two', ''], ['message', 'none', '']]],
    'keeps a leading tab' =>
      ["data:\ttab\n\n", [['message', "\ttab", '']]],
    'splits the field at the first colon only' =>
      ["data: a:b\n\n", [['message', 'a:b', '']]],
    'joins data lines with LF and drops the final LF' =>
      ["data: a\ndata:\ndata: b\ndata:\n\n", [['message', "a\n\nb\n", '']]],
    'ignores unknown and misspelled fields' =>
      ["data:test\n data\ndata\nfoobar:xxx\njustsometext\nData:x\ndata :x\ndata:test\n\n",
       [['message', "test\n\ntest", '']]],
    'parses fields exactly as the standard does' =>
      ["data:\0\ndata:  2\rData:1\ndata\0:2\ndata:1\r\0data:4\nda-ta:3\rdata_5\ndata:3\rdata:\r\n data:32\ndata:4\n\n",
       [['message', "\0\n 2\n1\n3\n\n4", '']]],
    'keeps the last event ID for later events' =>
      ["id: 1\ndata: a\n\ndata: b\n\n", [%w[message a 1], %w[message b 1]]],
    'resets the last event ID with an empty id' =>
      ["id:1\ndata:x\n\nid\ndata:y\n\n", [['message', 'x', '1'], ['message', 'y', '']]],
    'ignores an id containing NUL' =>
      ["id:1\ndata:x\n\nid:2\0\ndata:y\n\n", [%w[message x 1], %w[message y 1]]],
    'skips dispatch when the data buffer is empty and resets the event type' =>
      ["event: x\nid: 7\n\ndata: a\n\n", [%w[message a 7]]],
    'discards an event the stream ends in the middle of' =>
      ["data: a\n\nid: 2\ndata: b", [['message', 'a', '']]],
    'decodes UTF-8' =>
      ["data: ok…\n\n", [['message', 'ok…', '']]],
    'replaces invalid UTF-8 with U+FFFD' =>
      ["data: \xFF\xFEok\n\n".b, [['message', "\uFFFD\uFFFDok", '']]]
  }

  conformance.each do |description, (stream, events)|
    it description do
      expect(parse(stream)).to eq(events)
    end
  end

  it 'parses every case the same way whatever pieces it arrives in' do
    random = Random.new(42)

    conformance.each_value do |stream, events|
      expect(parse(stream, pieces: bytewise(stream))).to eq(events)
      20.times { expect(parse(stream, pieces: split_at_random(stream, random))).to eq(events) }
    end
  end

  it 'keeps a CRLF split across pieces as one line break' do
    expect(parse('', pieces: ["data: a\r", '', "\n", "\r", "\n"])).to eq([['message', 'a', '']])
  end

  it 'keeps a byte order mark split across pieces out of the first field' do
    expect(parse('', pieces: ["\xEF".b, "\xBB".b, "\xBFdata: a\n\n".b])).to eq([['message', 'a', '']])
  end

  it 'decodes characters split across pieces' do
    stream = "data: é€😀\n\n".b
    pieces = [stream.byteslice(0, 7), stream.byteslice(7, 4), stream.byteslice(11, 6), stream.byteslice(17..)]

    expect(parse('', pieces:)).to eq([['message', 'é€😀', '']])
  end

  it 'remembers the reconnection time, ignoring values that are not all digits' do
    parser = described_class.new
    parse("retry: 03000\n\nretry: 1000x\n\nretry\n\nretry: -1\n\nretry: ５\n\n", parser:)

    expect(parser.reconnection_time).to eq(3000)
  end

  it 'updates the last event ID even when no event is dispatched' do
    parser = described_class.new

    expect(parse("id: 5\n\n", parser:)).to be_empty
    expect(parser.last_event_id).to eq('5')
  end

  it 'leaves the last event ID unchanged until the event completes' do
    parser = described_class.new
    parse("id: 1\ndata: a\n\nid: 2\ndata: b\n", parser:)

    expect(parser.last_event_id).to eq('1')
  end

  it 'continues after the lines it already delivered when a handler raises' do
    parser = described_class.new
    events = []
    handler = proc do |_type, data|
      raise ArgumentError, data if data == 'boom'

      events << data
    end

    expect { parser.feed("data: boom\n\ndata: a\n\n", &handler) }.to raise_error(ArgumentError)
    parser.feed("data: b\n\n", &handler)

    expect(events).to eq(%w[a b])
  end

  describe 'compared with the event_stream_parser gem' do
    def gem_events(pieces)
      parser = EventStreamParser::Parser.new
      events = []
      pieces.each do |piece|
        parser.feed(piece) do |type, data, id|
          events << [type.empty? ? 'message' : type, data, id].map { |text| text.dup.force_encoding(Encoding::UTF_8) }
        end
      end
      events
    end

    def split_in_random_sizes(stream, random)
      pieces = []
      offset = 0
      while offset < stream.bytesize
        pieces << stream.byteslice(offset, random.rand(1..512))
        offset += pieces.last.bytesize
      end
      pieces
    end

    def recorded_streams
      Dir[File.expand_path('../../fixtures/vcr_cassettes/**/*.yml', __dir__)].flat_map do |path|
        text = File.read(path)
        next [] unless text.include?('text/event-stream')

        YAML.safe_load(text, aliases: true)['http_interactions'].filter_map do |interaction|
          body = interaction.dig('response', 'body', 'string')
          content_type = Array(interaction.dig('response', 'headers', 'Content-Type')).join
          body.b if content_type.include?('text/event-stream') && body && !body.empty?
        end
      end
    end

    it 'agrees on every recorded stream, however it is split' do
      random = Random.new(2026)
      streams = recorded_streams

      streams.each do |stream|
        splits = [[stream], stream.bytes.each_slice(64).map { |slice| slice.pack('C*') },
                  split_in_random_sizes(stream, random)]
        splits << bytewise(stream) if stream.bytesize < 8192
        splits.each { |pieces| expect(parse(stream, pieces:)).to eq(gem_events(pieces)) }
      end
      expect(streams.size).to be > 100
    end
  end
end
