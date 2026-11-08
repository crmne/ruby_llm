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
  let(:answering_servers) { [] }

  def closed_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1].tap { server.close }
  end

  def answering(status, headers = {}, body = '{}')
    server = TCPServer.new('127.0.0.1', 0)
    answering_servers << server
    answering_servers << Thread.new do
      loop do
        socket = server.accept
        head = +''
        while (line = socket.gets)
          head << line
          break if head.end_with?("\r\n\r\n")
        end
        next socket.close unless head.end_with?("\r\n\r\n")

        socket.read(head[/content-length: (\d+)/i, 1].to_i)
        fields = headers.merge('Content-Type' => 'application/json', 'Content-Length' => body.bytesize,
                               'Connection' => 'close').map { |name, value| "#{name}: #{value}\r\n" }.join
        socket.write("HTTP/1.1 #{status}\r\n#{fields}\r\n#{body}")
        socket.close
      end
    end
    "http://127.0.0.1:#{server.addr[1]}/mcp"
  end

  after do
    answering_servers.reverse_each { |server| server.is_a?(Thread) ? server.kill.join : server.close }
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

  context 'when the server answers that it is unavailable' do
    let(:url) { answering('503 Service Unavailable') }

    it_behaves_like 'a server the chat goes on without'
  end

  context 'when the server answers with an internal error' do
    let(:url) do
      answering('500 Internal Server Error', {}, '{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"boom"}}')
    end

    it_behaves_like 'a server the chat goes on without'
  end

  context 'when the server limits the rate of requests' do
    let(:url) { answering('429 Too Many Requests') }

    it_behaves_like 'a server the chat goes on without'
  end

  context "when the server's process exits" do
    it 'answers without its tools and tells the model' do
      chat.with_mcp(RubyLLM.mcp(command: [RbConfig.ruby, '-e', 'exit 1'], name: 'files'))

      expect(chat.ask('Hi').content).to eq('Done')

      expect(requests.first[:tools]).to be_empty
      note = requests.first[:messages].find { |message| message.role == :system }
      expect(note.content).to include("can't be reached").and include('files')
    end

    it 'still raises from a direct call to the server' do
      server = RubyLLM.mcp(command: [RbConfig.ruby, '-e', 'exit 1'], name: 'files')

      expect { server.tools }.to raise_error(RubyLLM::MCP::Error, /exited/)
    end
  end

  describe 'Retry-After' do
    before { stub_const('RubyLLM::MCP::Outages::BACKOFF', 0.05) }

    def down_after_backoff?(url)
      server = RubyLLM.mcp(url:, name: 'linear')
      RubyLLM::MCP::Outages.tools(server)
      sleep 0.1
      RubyLLM::MCP::Outages.down?(server)
    end

    it 'waits as long as a server that limits the rate asks, in seconds' do
      expect(down_after_backoff?(answering('429 Too Many Requests', 'Retry-After' => '30'))).to be(true)
    end

    it 'waits until the date an unavailable server asks for' do
      retry_at = (Time.now + 30).httpdate

      expect(down_after_backoff?(answering('503 Service Unavailable', 'Retry-After' => retry_at))).to be(true)
    end

    it 'waits the usual backoff without one, or with one it cannot read' do
      expect(down_after_backoff?(answering('503 Service Unavailable'))).to be(false)
      RubyLLM::MCP::Outages.clear
      expect(down_after_backoff?(answering('503 Service Unavailable', 'Retry-After' => 'soon'))).to be(false)
      RubyLLM::MCP::Outages.clear
      passed = (Time.now - 30).httpdate
      expect(down_after_backoff?(answering('503 Service Unavailable', 'Retry-After' => passed))).to be(false)
    end
  end

  it 'answers through the model while one server refuses the connection and another is unavailable' do
    reply = { id: 'resp_1', object: 'response', status: 'completed', model: model_for(:openai),
              output: [{ type: 'message', id: 'msg_1', status: 'completed', role: 'assistant',
                         content: [{ type: 'output_text', text: 'Hello', annotations: [] }] }],
              usage: { input_tokens: 5, output_tokens: 1, total_tokens: 6 } }
    model = answering('200 OK', {}, JSON.generate(reply)).sub(%r{/mcp\z}, '/v1')
    context = RubyLLM.context { |config| config.openai_api_base = model }
    refused = RubyLLM.mcp(url: "http://127.0.0.1:#{closed_port}/mcp", name: 'refused')
    down = RubyLLM.mcp(url: answering('503 Service Unavailable'), name: 'down')

    reply = context.chat(model: model_for(:openai), provider: :openai).with_mcp(refused, down).ask('Hi')

    expect(reply.content).to eq('Hello')
    expect(RubyLLM::MCP::Outages.down?(refused) && RubyLLM::MCP::Outages.down?(down)).to be(true)
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

  it 'still raises when the server answers that the credentials are missing' do
    chat.with_mcp(RubyLLM.mcp(url: answering('401 Unauthorized'), name: 'linear'))

    expect { chat.ask('Hi') }.to raise_error(RubyLLM::UnauthorizedError)
  end

  it 'still raises when the server does not know the endpoint' do
    chat.with_mcp(RubyLLM.mcp(url: answering('404 Not Found'), name: 'linear'))

    expect { chat.ask('Hi') }.to raise_error(RubyLLM::MCP::Error, /HTTP 404/)
  end

  describe 'a tool call the server fails' do
    let(:server) do
      RubyLLM.mcp(command: [RbConfig.ruby, File.expand_path('../fixtures/mcp/server.rb', __dir__)], name: 'files')
    end
    let(:chat) do
      done = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'echo', arguments: { 'text' => 'hi' })
      replies = [RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call }), done]
      seen = requests
      described_class.new(model: model_for(:anthropic)).with_mcp(server).tap do |built|
        allow(built.provider).to receive(:complete) do |messages, tools:, **|
          seen << { messages: messages.to_a, tools: tools.keys }
          replies.shift || done
        end
      end
    end

    after { server.close }

    def failing_with(error)
      allow(server).to receive(:run).and_raise(error)
      chat.ask('Echo hi')
    end

    def tool_result
      chat.messages.find { |message| message.role == :tool }.content
    end

    def unavailable(status)
      RubyLLM::MCP::Error.new("HTTP #{status}", response: Faraday::Response.new(status:))
    end

    shared_examples 'a failed call the turn goes on after' do |sits_out:|
      it 'gives the model a tool error and finishes the turn' do
        expect(failing_with(error).content).to eq('Done')

        expect(tool_result).to include('files').and include('failed')
      end

      it(sits_out ? 'sits the server out of the next request' : 'keeps offering its tools') do
        failing_with(error)

        expect(requests.last[:tools].include?(:echo)).to be(!sits_out)
        expect(RubyLLM::MCP::Outages.down?(server)).to be(sits_out)
      end
    end

    context 'when it answers that it is unavailable' do
      let(:error) { unavailable(503) }

      it_behaves_like 'a failed call the turn goes on after', sits_out: true
    end

    context 'when it limits the rate of requests' do
      let(:error) { unavailable(429) }

      it_behaves_like 'a failed call the turn goes on after', sits_out: true
    end

    context 'when the connection drops or times out' do
      let(:error) { RubyLLM::ConnectionError.new('Net::ReadTimeout') }

      it_behaves_like 'a failed call the turn goes on after', sits_out: true
    end

    context "when the server's process exits" do
      let(:error) { RubyLLM::MCP::Stdio::Unavailable.new('server.rb exited') }

      it_behaves_like 'a failed call the turn goes on after', sits_out: true
    end

    context 'when it answers with a JSON-RPC error' do
      let(:error) { RubyLLM::MCP::Error.new('Internal error', code: -32_603) }

      it_behaves_like 'a failed call the turn goes on after', sits_out: false
    end

    it 'still raises when the server refuses the credentials' do
      expect { failing_with(RubyLLM::UnauthorizedError.new('no')) }.to raise_error(RubyLLM::UnauthorizedError)
    end

    it 'still raises when the server does not know the endpoint' do
      expect { failing_with(unavailable(404)) }.to raise_error(RubyLLM::MCP::Error, 'HTTP 404')
    end

    it 'lets a handler the server declares answer instead' do
      server.class.rescue_from(RubyLLM::MCP::Error) { |failure| { error: "Handled #{failure.message}" } }

      failing_with(unavailable(503))

      expect(tool_result).to include('Handled HTTP 503')
      expect(RubyLLM::MCP::Outages.down?(server)).to be(false)
    end

    it 'still raises from a direct call to the server' do
      server.tools
      allow(server).to receive(:call_tool).and_raise(unavailable(503))

      expect { server.call(:echo, text: 'hi') }.to raise_error(RubyLLM::MCP::Error, 'HTTP 503')
    end
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
