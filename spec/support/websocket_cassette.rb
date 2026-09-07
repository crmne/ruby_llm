# frozen_string_literal: true

require_relative 'realtime_credentials'

module WebsocketCassette
  class Socket
    def initialize(events, socket = nil)
      @events = events
      @socket = socket
      @outgoing = []
    end

    def send_binary(data)
      @outgoing << { 'binary_sha256' => Digest::SHA256.hexdigest(data), 'bytes' => data.bytesize }
      @socket&.send_binary(data)
    end

    def send_text(data)
      @outgoing << WebsocketCassette.sanitize(JSON.parse(data))
      @socket&.send_text(data)
    end

    def close
      @socket&.close
    end

    def each_message(write:)
      if @socket
        @events['incoming'] = []
        @socket.each_message(write: ->(_socket) { write.call(self) }) do |message|
          @events['incoming'] << WebsocketCassette.sanitize(JSON.parse(message))
          yield message
        end
        @events['outgoing'] = @outgoing
      else
        writer = Thread.new { write.call(self) }
        @events.fetch('incoming').each { |event| yield JSON.generate(event) }
        writer.value
        raise 'Recorded WebSocket request does not match' unless @outgoing == @events.fetch('outgoing')
      end
    ensure
      writer&.kill unless writer&.join(1)
    end
  end

  def self.sanitize(value)
    RealtimeCredentials.sanitize(value, redact_audio: true)
  end

  def with_websocket_cassette(name, key:)
    path = File.expand_path("../fixtures/websocket_cassettes/#{name}.json", __dir__)
    recording = !File.exist?(path)
    ensure_websocket_recording_allowed(path, key) if recording
    fixture = recording ? {} : RealtimeCredentials.sanitize(JSON.parse(File.read(path)))
    stub_websocket_cassette(fixture, recording:)

    yield
    return unless recording

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{JSON.pretty_generate(fixture)}\n")
  end

  def stub_websocket_cassette(fixture, recording:)
    original = RubyLLM::Transport::WebsocketConnection.method(:open)

    allow(RubyLLM::Transport::WebsocketConnection).to receive(:open) do |url, headers:, config:, &block|
      uri = URI.parse(RealtimeCredentials.sanitize_url(url))
      uri.query ||= ''
      if recording
        fixture['url'] = uri.to_s
        fixture['recorded_at'] = Time.now.utc.iso8601
        original.call(url, headers:, config:) { |socket| block.call(WebsocketCassette::Socket.new(fixture, socket)) }
      else
        expect(uri.to_s).to eq(fixture.fetch('url'))
        socket = WebsocketCassette::Socket.new(fixture)
        block.call(socket)
      end
    end
  end

  def ensure_websocket_recording_allowed(path, key)
    raise "Missing WebSocket recording: #{path}" if ENV['CI'] || !RSpec.current_example.metadata[:live]

    skip "Set #{key} to record this WebSocket fixture" if ENV[key].to_s.empty?
  end
end
