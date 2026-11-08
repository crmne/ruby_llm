# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::Outages do
  include_context 'with configured RubyLLM'

  let(:transport) do
    Class.new do
      attr_accessor :failure, :annotations

      def request(message, **)
        case message[:method]
        when 'server/discover' then result(message, { 'supportedVersions' => ['2026-07-28'] })
        when 'tools/list'
          result(message, { 'tools' => [{ 'name' => 'create_issue', 'inputSchema' => {},
                                          'annotations' => annotations }.compact] })
        else failure.is_a?(Exception) ? raise(failure) : reply_error(message, failure)
        end
      end

      def notify(*, **) = nil
      def cancel(*, **) = nil
      def close = nil

      private

      def result(message, value) = { 'jsonrpc' => '2.0', 'id' => message[:id], 'result' => value }
      def reply_error(message, error) = { 'jsonrpc' => '2.0', 'id' => message[:id], 'error' => error }
    end.new
  end

  let(:server_class) do
    server = transport
    Class.new(RubyLLM::MCP) do
      transport server
      self.default_name = 'linear'
    end
  end

  let(:server) { server_class.new }
  let(:chat) do
    done = RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1)
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'create_issue', arguments: {})
    replies = [RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call }), done]
    RubyLLM.chat(model: model_for(:openai), provider: :openai).with_mcp(server).tap do |built|
      allow(built.provider).to receive(:complete) { replies.shift || done }
    end
  end

  before { allow(RubyLLM.logger).to receive(:warn) }

  def unavailable(status, provider_message: nil)
    RubyLLM::MCP::Error.new(provider_message ? nil : "linear.internal.example answered HTTP #{status}",
                            provider_message:, provider: 'linear.internal.example',
                            response: Faraday::Response.new(status:))
  end

  def dropped
    RubyLLM::ConnectionError.new('Failed to open TCP connection to linear.internal.example:443',
                                 provider: 'linear.internal.example')
  end

  def tool_result(failure)
    transport.failure = failure
    chat.ask('File it')
    chat.messages.find(&:tool_result?).content
  end

  around do |example|
    described_class.clear
    saved = [RubyLLM::Tool, RubyLLM::MCP::Tool].to_h { |klass| [klass, klass.rescue_handlers.dup] }
    redact = RubyLLM.config.redact_error_messages
    example.run
  ensure
    described_class.clear
    saved.each { |klass, handlers| klass.instance_variable_set(:@rescue_handlers, handlers) }
    RubyLLM.config.redact_error_messages = redact
  end

  describe 'with a catch-all handler on every tool' do
    before { RubyLLM::Tool.rescue_from(StandardError) { 'swallowed by the catch-all' } }

    it 'still gives the model the outage tool error and sits the server out' do
      result = tool_result(unavailable(503))

      expect(result).to include('The linear MCP server failed')
      expect(described_class.down?(server)).to be(true)
    end

    it 'lets a handler on the MCP class win' do
      server_class.rescue_from(RubyLLM::MCP::Error) { 'from the server' }

      expect(tool_result(unavailable(503))).to eq('from the server')
      expect(described_class.down?(server)).to be(false)
    end

    it 'lets a handler on MCP::Tool win' do
      RubyLLM::MCP::Tool.rescue_from(RubyLLM::MCP::Error) { 'from the MCP tools' }

      expect(tool_result(unavailable(503))).to eq('from the MCP tools')
    end
  end

  describe 'with redacted error messages' do
    before { RubyLLM.config.redact_error_messages = true }

    it 'gives the model what the server wrote' do
      result = tool_result({ 'code' => -32_000, 'message' => 'Team ENG is archived' })

      expect(result).to include('The linear MCP server failed: Team ENG is archived')
    end

    it 'keeps it out of the exception a direct call raises' do
      transport.failure = { 'code' => -32_000, 'message' => 'Team ENG is archived' }

      expect { server.call(:create_issue) }
        .to raise_error(RubyLLM::MCP::Error) { |error| expect(error.message).not_to include('archived') }
    end

    it 'keeps it out of the warning' do
      tool_result(unavailable(503, provider_message: 'Team ENG is archived'))

      expect(RubyLLM.logger).to have_received(:warn).with(satisfy { |line| !line.include?('archived') })
    end
  end

  describe 'the warning' do
    it "names the server and the error's class, not the host" do
      tool_result(dropped)

      expect(RubyLLM.logger).to have_received(:warn)
        .with('MCP server linear is unreachable, so its tools sit out: RubyLLM::ConnectionError')
    end

    it 'names the status the server answered' do
      tool_result(unavailable(503))

      expect(RubyLLM.logger).to have_received(:warn)
        .with('MCP server linear is unreachable, so its tools sit out: RubyLLM::MCP::Error, HTTP 503')
    end
  end

  describe 'a call that may have partly run' do
    partly_run = 'The call may have partly run, so check before trying it again.'

    it 'says so for a tool that is not idempotent' do
      expect(tool_result(dropped)).to eq('{"error":"The linear MCP server failed: Failed to open TCP connection ' \
                                         "to linear.internal.example:443. #{partly_run}\"}")
    end

    it 'says so when the server failed it with a 5xx status' do
      expect(tool_result(unavailable(502, provider_message: 'Bad gateway.')))
        .to eq("{\"error\":\"The linear MCP server failed: Bad gateway. #{partly_run}\"}")
    end

    it 'says so for an idempotent tool that is destructive' do
      transport.annotations = { 'idempotentHint' => true, 'destructiveHint' => true }

      expect(tool_result(dropped)).to include(partly_run)
    end

    it 'says nothing for an idempotent tool that is not destructive' do
      transport.annotations = { 'idempotentHint' => true, 'destructiveHint' => false }

      expect(tool_result(dropped)).not_to include('partly run')
    end

    it 'says nothing for a tool that only reads' do
      transport.annotations = { 'readOnlyHint' => true }

      expect(tool_result(dropped)).not_to include('partly run')
    end

    it 'says nothing when the server limited the rate, since it never ran the call' do
      expect(tool_result(unavailable(429))).not_to include('partly run')
    end

    it 'says nothing when the server answered with a JSON-RPC error' do
      expect(tool_result({ 'code' => -32_603, 'message' => 'Internal error' })).not_to include('partly run')
    end
  end
end
