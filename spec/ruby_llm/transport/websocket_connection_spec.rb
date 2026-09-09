# frozen_string_literal: true

require 'spec_helper'
require 'websocket/driver'

RSpec.describe RubyLLM::Transport::WebsocketConnection do
  let(:config) { RubyLLM::Configuration.new }

  it 'blocks accidental external connections in non-live specs' do
    expect { described_class.open('wss://example.com', headers: {}, config:) { nil } }
      .to raise_error(RuntimeError, /External socket connections require a :live spec/)
  end

  def with_server(echo: true)
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    worker = Thread.new { run_server(server.accept, echo:) }
    yield "ws://127.0.0.1:#{port}", worker
  ensure
    server&.close
    worker&.join(1)
    worker&.kill if worker&.alive?
  end

  def run_server(socket, echo:)
    driver = WebSocket::Driver.server(socket)
    driver.on(:connect) { driver.start }
    if echo
      driver.on(:message) do |event|
        event.data.encoding == Encoding::BINARY ? driver.binary(event.data) : driver.text(event.data)
      end
    end
    driver.on(:close) { socket.close }
    driver.parse(socket.readpartial(16_384)) until socket.closed?
  rescue IOError, Errno::ECONNRESET
    nil
  ensure
    socket.close unless socket.closed?
  end

  it 'performs a real WebSocket handshake and exchanges frames' do
    with_server do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        connection.send_text('Hello Ruby')
        expect(connection.read).to eq('Hello Ruby')
      end
    end
  end

  it 'closes the socket when the caller raises' do
    with_server do |url, worker|
      expect do
        described_class.open(url, headers: {}, config:) { raise 'Stopped' }
      end.to raise_error(RuntimeError, 'Stopped')
      expect(worker.join(1)).to eq(worker)
    end
  end

  it 'reads available frames without waiting when the socket has no complete message' do
    with_server do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expect(connection.read_available).to be_nil
        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 0.1

        connection.send_text('Queued cancellation')
        readable = connection.instance_variable_get(:@socket)
        expect(readable.wait_readable(1)).to be_truthy
        expect(connection.read_available).to eq('Queued cancellation')
        expect(connection.read_available).to be_nil
      end
    end
  end

  it 'keeps partial frames buffered without blocking or losing their bytes' do
    with_server(echo: false) do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        transport = connection.instance_variable_get(:@socket)
        allow(transport).to receive(:read_nonblock).with(16_384, exception: false)
                                                   .and_return("\x81\x05he".b, :wait_readable,
                                                               'llo'.b, :wait_readable)
        expect(connection.read_available).to be_nil
        expect(connection.read_available).to eq('hello')
      end
    end
  end

  it 'preserves arbitrary binary frame bytes' do
    with_server do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        connection.send_binary("\xFF\x00\x80".b)
        expect(connection.read).to eq("\xFF\x00\x80".b)
      end
    end
  end

  it 'stops the writer when the connection closes before an acknowledgement' do
    writer = nil
    with_server do |url, _worker|
      expect do
        described_class.open(url, headers: {}, config:) do |connection|
          write = lambda do |socket|
            writer = Thread.current
            socket.send_text('Waiting for an acknowledgement')
            Queue.new.pop
          end
          connection.each_message(write:) { connection.close }
        end
      end.to raise_error(RubyLLM::Error, /before outgoing messages finished/)
    end
    expect(writer).not_to be_alive
  end

  it 'rejects an untrusted TLS certificate' do
    server = TCPServer.new('127.0.0.1', 0)
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 60
    certificate.sign(key, OpenSSL::Digest.new('SHA256'))
    context = OpenSSL::SSL::SSLContext.new
    context.cert = certificate
    context.key = key
    worker = Thread.new do
      socket = OpenSSL::SSL::SSLSocket.new(server.accept, context)
      socket.sync_close = true
      socket.accept
    rescue OpenSSL::SSL::SSLError
      nil
    ensure
      socket&.close
    end

    expect do
      described_class.open("wss://127.0.0.1:#{server.addr[1]}", headers: {}, config:) { nil }
    end.to raise_error(OpenSSL::SSL::SSLError, /certificate verify failed/)
  ensure
    server&.close
    worker&.join(1)
  end

  it 'bounds a read when the peer sends no frames' do
    config.request_timeout = 0.05
    with_server(echo: false) do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        expect { connection.read }.to raise_error(RubyLLM::Error, /timed out/)
      end
    end
  end

  it 'ends a blocked read when another thread closes the connection' do
    with_server(echo: false) do |url, _worker|
      described_class.open(url, headers: {}, config:) do |connection|
        entered = Queue.new
        allow(connection).to receive(:wait_for_socket).and_wrap_original do |original, *args|
          entered << true
          original.call(*args)
        end
        reader = Thread.new { connection.read }
        entered.pop
        connection.close

        expect(reader.join(1)).to eq(reader)
        expect(reader.value).to be_nil
      ensure
        reader&.kill&.join
      end
    end
  end

  it 'rejects a configured proxy before opening a socket' do
    config.http_proxy = 'socks5://localhost:1080'
    allow(Socket).to receive(:tcp)

    expect { described_class.open('wss://example.com', headers: {}, config:) { nil } }
      .to raise_error(ArgumentError, /do not support HTTP proxies/)
    expect(Socket).not_to have_received(:tcp)
  end

  it 'requires the optional driver with an actionable error' do
    connection = described_class.new('wss://example.com', headers: {}, config:)
    allow(connection).to receive(:require).with('websocket/driver').and_raise(LoadError)

    expect { connection.connect }.to raise_error(LoadError, /Add gem "websocket-driver"/)
  end

  it 'rejects unsupported URL schemes and URL credentials' do
    expect { described_class.new('https://example.com', headers: {}, config:) }
      .to raise_error(ArgumentError, /must use ws or wss/)
    expect { described_class.new('wss://secret@example.com', headers: {}, config:) }
      .to raise_error(ArgumentError, /must not contain credentials/)
  end

  it 'fails if the peer closes without a WebSocket close frame' do
    server = TCPServer.new('127.0.0.1', 0)
    worker = Thread.new { server.accept.close }

    expect do
      described_class.open("ws://127.0.0.1:#{server.addr[1]}", headers: {}, config:) { nil }
    end.to raise_error(RubyLLM::Error, /without a close frame/)
  ensure
    server&.close
    worker&.join(1)
  end
end
