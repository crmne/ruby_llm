# frozen_string_literal: true

require 'spec_helper'
require 'socket'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  around do |example|
    WebMock.disable!
    RubyLLM::MCP::Outages.clear
    example.run
  ensure
    WebMock.enable!
    RubyLLM::MCP::Outages.clear
  end

  let(:requests) { [] }
  let(:chat) do
    ok = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    seen = requests
    described_class.new(model: model_for(:anthropic)).tap do |built|
      allow(built.provider).to receive(:complete) do |messages, tools:, **|
        seen << { messages: messages.to_a, tools: tools.keys }
        ok
      end
    end
  end

  def closed_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1].tap { server.close }
  end

  def elapsed
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  shared_examples 'a server the chat goes on without' do
    it 'answers without its tools and tells the model' do
      chat.with_mcp(RubyLLM.mcp(url:, name: 'linear'))

      expect(chat.ask('Hi').content).to eq('Done')

      expect(requests.first[:tools]).to be_empty
      note = requests.first[:messages].find { |message| message.role == :system }
      expect(note.content).to include("can't be reached").and include('linear')
    end

    it 'leaves the note out of the transcript' do
      chat.with_mcp(RubyLLM.mcp(url:, name: 'linear')).ask('Hi')

      expect(chat.messages.map(&:role)).to eq(%i[user assistant])
    end

    it 'logs a warning and emits one event' do
      events = []
      instrumenter = Class.new do
        define_method(:instrument) do |name, payload = {}, &block|
          events << [name, payload] if name == 'mcp_unreachable.ruby_llm'
          block&.call(payload)
        end
      end.new
      allow(RubyLLM.config).to receive(:instrumenter).and_return(instrumenter)
      allow(RubyLLM.logger).to receive(:warn).and_call_original

      2.times { chat.with_mcp(RubyLLM.mcp(url:, name: 'linear')).ask('Hi') }

      expect(RubyLLM.logger).to have_received(:warn).with(/linear is unreachable/).once
      expect(events.map { |_, payload| payload[:server] }).to eq(['linear'])
    end

    it 'does not try again on the next turn, even from new objects' do
      stub_const('RubyLLM::MCP::Client::DISCOVERY_TIMEOUT', 0.3)
      chat.with_mcp(RubyLLM.mcp(url:, name: 'linear')).ask('Hi')

      fresh = described_class.new(model: model_for(:anthropic))
      allow(fresh.provider).to receive(:complete)
        .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1))
      fresh.with_mcp(RubyLLM.mcp(url:, name: 'linear'))

      expect(elapsed { fresh.ask('Again') }).to be < 0.2
    end
  end

  context 'when the connection is refused' do
    let(:url) { "http://127.0.0.1:#{closed_port}/mcp" }

    it_behaves_like 'a server the chat goes on without'
  end

  context 'when the server never answers' do
    let(:silent) { TCPServer.new('127.0.0.1', 0) }
    let(:url) { "http://127.0.0.1:#{silent.addr[1]}/mcp" }

    around do |example|
      accepted = []
      acceptor = Thread.new { loop { accepted << silent.accept } }
      example.run
    ensure
      acceptor.kill.join
      silent.close
      accepted.each(&:close)
    end

    before { stub_const('RubyLLM::MCP::Client::DISCOVERY_TIMEOUT', 0.3) }

    it_behaves_like 'a server the chat goes on without'
  end

  it 'tries again after the backoff and offers the tools once the server is back' do
    fixture = File.expand_path('../fixtures/mcp/server.rb', __dir__)
    server = RubyLLM.mcp(command: [RbConfig.ruby, fixture], name: 'files')
    chat.with_mcp(server)
    allow(server).to receive(:tools).and_raise(RubyLLM::ConnectionError, 'down')
    stub_const('RubyLLM::MCP::Outages::BACKOFF', 0.05)
    chat.ask('Hi')
    sleep 0.1
    allow(server).to receive(:tools).and_call_original

    chat.ask('Again')

    expect(requests.last[:tools]).to include(:echo)
    expect(requests.last[:messages].map(&:role)).not_to include(:system)
  ensure
    server.close
  end

  it 'keeps the tools a chat already listed when another chat finds the server down' do
    fixture = File.expand_path('../fixtures/mcp/server.rb', __dir__)
    server = RubyLLM.mcp(command: [RbConfig.ruby, fixture], name: 'files')
    chat.with_mcp(server).ask('Hi')
    failing = RubyLLM.mcp(command: [RbConfig.ruby, fixture], name: 'files')
    allow(failing).to receive(:tools).and_raise(RubyLLM::ConnectionError, 'down')
    expect(RubyLLM::MCP::Outages.tools(failing)).to eq([])

    chat.ask('Again')

    expect(requests.last[:tools]).to include(:echo)
  ensure
    server.close
  end

  it 'keeps servers apart when their settings depend on runtime state' do
    address = "http://127.0.0.1:#{closed_port}/mcp"
    down = RubyLLM.mcp(url: -> { address }, name: 'linear')
    other = down.class.new
    RubyLLM::MCP::Outages.tools(down)

    expect(RubyLLM::MCP::Outages.down?(down)).to be(true)
    expect(RubyLLM::MCP::Outages.down?(other)).to be(false)
  end

  it 'reports an outage once when chats find it at the same time' do
    server = RubyLLM.mcp(url: "http://127.0.0.1:#{closed_port}/mcp", name: 'linear')
    allow(RubyLLM.logger).to receive(:warn).and_call_original
    allow(RubyLLM::MCP::Outages).to receive(:down?).and_return(false)

    2.times { RubyLLM::MCP::Outages.tools(server) }

    expect(RubyLLM.logger).to have_received(:warn).with(/unreachable/).once
  end

  it 'still raises from a direct call to the server' do
    server = RubyLLM.mcp(url: "http://127.0.0.1:#{closed_port}/mcp", name: 'linear')

    expect { server.tools }.to raise_error(RubyLLM::ConnectionError)
  end

  it 'still raises when the server refuses the credentials' do
    server = RubyLLM.mcp(transport: Class.new do
      def request(*, **) = raise(RubyLLM::UnauthorizedError, 'no')
      def notify(*, **) = nil
      def cancel(*, **) = nil
      def close = nil
    end.new, name: 'linear')
    chat.with_mcp(server)

    expect { chat.ask('Hi') }.to raise_error(RubyLLM::UnauthorizedError)
  end
end
