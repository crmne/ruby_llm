# frozen_string_literal: true

require 'spec_helper'
require 'socket'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
    server.close
    threads.each(&:kill)
    sockets.each(&:close)
  end

  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:sockets) { [] }
  let(:threads) { [] }
  let(:requests) { Queue.new }

  def primary = 'claude-haiku-4-5'

  def context(idle: 1, timeout: 30, retries: 0, adapter: :net_http)
    port = server.addr[1]
    RubyLLM.context do |config|
      config.faraday_adapter = adapter
      config.anthropic_api_base = "http://127.0.0.1:#{port}"
      config.request_timeout = timeout
      config.stream_idle_timeout = idle
      config.max_retries = retries
      config.retry_interval = 0.01
    end
  end

  def event(name, data)
    "event: #{name}\ndata: #{data.to_json}\n\n"
  end

  def start_events
    head = "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n\r\n"
    head + event(:message_start, type: 'message_start',
                                 message: { id: 'm', type: 'message', role: 'assistant', model: 'claude', content: [],
                                            usage: { input_tokens: 7, output_tokens: 0 } }) +
      event(:content_block_start, type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' })
  end

  def text_event(text)
    event(:content_block_delta, type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: })
  end

  def end_events
    event(:content_block_stop, type: 'content_block_stop', index: 0) +
      event(:message_delta, type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 3 }) +
      event(:message_stop, type: 'message_stop')
  end

  # Serves every request in its own thread: the block gets the socket and
  # the model the request asked for, after the whole request is read.
  def serve(&respond)
    threads << Thread.new do
      loop do
        socket = server.accept
        sockets << socket
        threads << Thread.new(socket) do |client|
          head = client.gets("\r\n\r\n")
          body = JSON.parse(client.read(head[/^content-length: (\d+)/i, 1].to_i))
          requests << body['model']
          respond.call(client, body['model'])
        rescue IOError, SystemCallError
          nil
        end
      end
    rescue IOError, SystemCallError
      nil
    end
  end

  def answer(socket, text)
    socket.write((text.empty? ? '' : start_events + text_event(text)) + end_events)
    socket.close
  end

  # Returns how many seconds the block took and what it returned or raised.
  def timed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    outcome = begin
      yield
    rescue RubyLLM::Error => e
      e
    end
    [Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, outcome]
  end

  def stream(chat)
    timed { chat.ask('Hi') { |_chunk| nil } }
  end

  def timeout_error
    be_a(RubyLLM::ConnectionError).and(have_attributes(timeout?: true))
  end

  def silent
    serve { |_socket, _model| nil }
  end

  shared_examples 'an idle timeout' do |adapter|
    let(:chat) { context(adapter:).chat(model: primary, provider: :anthropic) }

    it 'times out a provider that accepts the request and never answers' do
      silent

      seconds, error = stream(chat)

      expect(error).to timeout_error
      expect(seconds).to be < 10
    end

    it 'times out a stream that goes quiet after its first chunk' do
      serve { |socket, _model| socket.write(start_events + text_event('Hel')) }

      seconds, error = stream(chat)

      expect(error).to timeout_error
      expect(seconds).to be < 10
    end

    it 'lets a slow stream run past it while chunks keep coming' do
      serve do |socket, _model|
        socket.write(start_events)
        6.times do |index|
          sleep 0.5
          socket.write(text_event(index.to_s))
        end
        answer(socket, '')
      end

      seconds, reply = stream(chat)

      expect(reply.content).to eq('012345')
      expect(seconds).to be >= 3
    end
  end

  it_behaves_like 'an idle timeout', :net_http

  context 'with a persistent connection' do
    before { require 'faraday/net_http_persistent' }

    it_behaves_like 'an idle timeout', :net_http_persistent
  end

  it 'moves on to the fallback when the provider sends nothing' do
    serve { |socket, model| answer(socket, 'From the fallback') unless model.start_with?(primary) }
    chat = context.chat(model: primary, provider: :anthropic).with_fallbacks('claude-sonnet-4-5')

    seconds, reply = stream(chat)

    expect(reply.content).to eq('From the fallback')
    expect(Array.new(requests.size) { requests.pop }).to match([start_with(primary), 'claude-sonnet-4-5'])
    expect(seconds).to be < 10
  end

  it 'leaves streams to the request timeout when it is not set' do
    silent

    seconds, error = stream(context(idle: nil, timeout: 2).chat(model: primary, provider: :anthropic))

    expect(error).to timeout_error
    expect(seconds).to be >= 2
  end

  it 'leaves requests that do not stream to the request timeout' do
    silent
    chat = context(idle: 0.2, timeout: 2).chat(model: primary, provider: :anthropic)

    seconds, error = timed { chat.ask('Hi') }

    expect(error).to timeout_error
    expect(seconds).to be >= 2
  end
end
