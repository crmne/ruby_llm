# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai) }

  def failing_tool(error = RuntimeError.new('the service broke'), name: 'lookup', &)
    Class.new(described_class) do
      define_singleton_method(:tool_name) { name }
      define_method(:execute) { raise error }
      class_eval(&) if block_given?
    end
  end

  def calls(*names, arguments: {})
    tool_calls = names.each_with_index.to_h do |name, index|
      ["call_#{index}", RubyLLM::ToolCall.new(id: "call_#{index}", name:, arguments:)]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def results
    chat.messages.select(&:tool_result?).map(&:content)
  end

  def result_of(tool, name: 'lookup')
    chat.with_tools(tool)
    allow(chat.provider).to receive(:complete).and_return(calls(name), answer)
    chat.ask('Go')
    results.sole
  end

  describe '.rescue_from' do
    it 'returns the named handler result as the call result' do
      tool = failing_tool do
        rescue_from RuntimeError, with: :handle

        private

        def handle(error) = { error: "Failed: #{error.message}" }
      end

      expect(result_of(tool)).to eq('{"error":"Failed: the service broke"}')
    end

    it 'calls a zero-arity handler without arguments' do
      tool = failing_tool do
        rescue_from RuntimeError, with: :handle

        private

        def handle = 'handled'
      end

      expect(result_of(tool)).to eq('handled')
    end

    it 'runs a block handler on the tool instance' do
      tool = failing_tool { rescue_from(RuntimeError) { |error| "#{name}: #{error.message}" } }

      expect(result_of(tool)).to eq('lookup: the service broke')
    end

    it 'prefers the handler declared last' do
      tool = failing_tool do
        rescue_from(StandardError) { 'general' }
        rescue_from(RuntimeError) { 'specific' }
      end

      expect(result_of(tool)).to eq('specific')
    end

    it 'looks up exception classes named as Strings when an exception is raised' do
      tool = failing_tool(RubyLLM::RateLimitError.new('slow down')) do
        rescue_from('RubyLLM::MissingSpecError', 'RubyLLM::RateLimitError') { 'named' }
      end

      expect(result_of(tool)).to eq('named')
    end

    it 'raises exceptions no handler matches' do
      tool = failing_tool { rescue_from(ArgumentError) { 'unused' } }

      expect { result_of(tool) }.to raise_error(RuntimeError, 'the service broke')
    end

    it 'raises what a handler re-raises, running the handler once' do
      runs = 0
      tool = failing_tool do
        rescue_from(RuntimeError) do
          runs += 1
          raise
        end
      end

      expect { result_of(tool) }.to raise_error(RuntimeError, 'the service broke')
      expect(runs).to eq(1)
    end

    it 'lets a handler end the turn with halt' do
      tool = failing_tool { rescue_from(RuntimeError) { halt 'stopped' } }
      chat.with_tools(tool)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup'), answer)

      chat.ask('Go')

      expect(chat.messages.last).to have_attributes(content: 'stopped', finish_reason: :halted)
      expect(chat.provider).to have_received(:complete).once
    end

    it 'leaves questions from ask to the chat' do
      tool = Class.new(described_class) do
        def self.tool_name = 'booking'
        rescue_from(StandardError) { 'swallowed' }
        def execute = ask('Window or aisle?')
      end
      chat.with_tools(tool)
      allow(chat.provider).to receive(:complete).and_return(calls('booking'), answer)

      chat.ask('Go')

      expect(chat.pending_questions.map(&:message)).to eq(['Window or aisle?'])
    end

    it 'leaves cancellations alone' do
      tool = failing_tool(RubyLLM::CancelledError.new) { rescue_from(StandardError) { 'swallowed' } }

      expect { result_of(tool) }.to raise_error(RubyLLM::CancelledError)
    end

    it 'validates its arguments as Agent.rescue_from does' do
      expect { failing_tool { rescue_from RuntimeError } }.to raise_error(ArgumentError, /needs a handler/)
      expect { failing_tool { rescue_from(RuntimeError, with: :handle) { nil } } }
        .to raise_error(ArgumentError, /not both/)
      expect { failing_tool { rescue_from(Interrupt) { nil } } }.to raise_error(ArgumentError, /not a StandardError/)
    end

    it 'gives subclasses the handlers their parents declare, even after the subclass is defined' do
      parent = failing_tool
      child = Class.new(parent)
      parent.rescue_from(RuntimeError) { 'added later' }

      expect(result_of(child)).to eq('added later')
    end

    it 'prefers a subclass handler to its parent one' do
      parent = failing_tool
      child = Class.new(parent) { rescue_from(RuntimeError) { 'from the child' } }
      parent.rescue_from(RuntimeError) { 'from the parent' }

      expect(result_of(child)).to eq('from the child')
      expect(child.rescue_handlers.size).to eq(1)
    end

    it 'covers a tool that overrides call' do
      tool = Class.new(described_class) do
        def self.tool_name = 'lookup'
        rescue_from(RuntimeError) { |error| "Recovered: #{error.message}" }
        def call(**) = raise('call broke')
      end

      expect(result_of(tool)).to eq('Recovered: call broke')
    end

    it 'leaves a call you make yourself to you' do
      tool = failing_tool { rescue_from(RuntimeError) { 'swallowed' } }

      expect { tool.new.call }.to raise_error(RuntimeError, 'the service broke')
    end

    it 'handles an exception from resume' do
      tool = Class.new(described_class) do
        def self.tool_name = 'signature'
        rescue_from(RuntimeError) { |error| "Resume failed: #{error.message}" }
        def execute = RubyLLM::Task.new(status: :working)
        def resume(_task, **) = raise('envelope missing')
      end
      chat.with_tools(tool)
      allow(chat.provider).to receive(:complete).and_return(calls('signature'), answer)

      chat.ask('Go')
      chat.complete

      expect(results).to eq(['Resume failed: envelope missing'])
    end

    it 'resumes with the model arguments as keywords' do
      tool = Class.new(described_class) do
        def self.tool_name = 'signature'
        def execute(envelope:) = RubyLLM::Task.new(status: :working, data: { 'envelope' => envelope })
        def resume(_task, envelope:) = "Signed #{envelope}"
      end
      chat.with_tools(tool)
      allow(chat.provider).to receive(:complete).and_return(calls('signature', arguments: { 'envelope' => 'E-1' }),
                                                            answer)

      chat.ask('Go')
      chat.complete

      expect(results).to eq(['Signed E-1'])
    end
  end

  describe 'in a chat' do
    it 'raises a tool exception without a handler, as before' do
      chat.with_tools(failing_tool)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup'), answer)

      expect { chat.ask('Go') }.to raise_error(RuntimeError, 'the service broke')
    end

    [nil, :threads, :fibers].each do |mode|
      it "sends the handler result to the model with #{mode || 'sequential'} tool calls" do
        flaky = failing_tool { rescue_from(RuntimeError) { |error| { error: error.message } } }
        steady = Class.new(described_class) do
          def self.tool_name = 'steady'
          def execute = 'fine'
        end
        chat.with_tools(flaky, steady).with_tool_options(concurrency: mode)
        allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'steady'), answer)

        response = chat.ask('Go')

        expect(response.content).to eq('done')
        expect(results).to contain_exactly('{"error":"the service broke"}', 'fine')
      end
    end

    it 'reports the handler result to after_tool_result' do
      seen = []
      chat.with_tools(failing_tool { rescue_from(RuntimeError) { 'recovered' } })
          .after_tool_result { |result| seen << result }
      allow(chat.provider).to receive(:complete).and_return(calls('lookup'), answer)

      chat.ask('Go')

      expect(seen).to eq(['recovered'])
    end
  end

  describe 'MCP tools' do
    let(:transport) do
      Class.new do
        attr_reader :calls

        def request(message, **)
          (@calls ||= []) << message[:params] if message[:method] == 'tools/call'
          case message[:method]
          when 'server/discover' then result(message, { 'supportedVersions' => ['2026-07-28'] })
          when 'tools/list' then result(message, { 'tools' => [{ 'name' => 'read_notes', 'inputSchema' => {} }] })
          else { 'jsonrpc' => '2.0', 'id' => message[:id], 'error' => { 'code' => -32_000, 'message' => 'Asleep' } }
          end
        end

        def notify(*, **) = nil
        def cancel(*, **) = nil
        def close = nil

        private

        def result(message, value) = { 'jsonrpc' => '2.0', 'id' => message[:id], 'result' => value }
      end
    end

    def laptop_class(&)
      server = transport.new
      Class.new(RubyLLM::MCP) do
        transport server
        inputs :owner
        self.default_name = 'laptop'
        class_eval(&) if block_given?
      end
    end

    around do |example|
      saved = RubyLLM::MCP::Tool.rescue_handlers.dup
      example.run
    ensure
      RubyLLM::MCP::Tool.instance_variable_set(:@rescue_handlers, saved)
    end

    it 'raises a server error without a handler, as before' do
      chat.with_mcp(laptop_class.new(owner: 'Ada'))
      allow(chat.provider).to receive(:complete).and_return(calls('read_notes'), answer)

      expect { chat.ask('Read my notes') }.to raise_error(RubyLLM::MCP::Error, /Asleep/)
    end

    it 'runs a handler declared on the MCP class on the MCP instance' do
      laptop = laptop_class do
        rescue_from RubyLLM::MCP::Error, with: :laptop_failed

        private

        def laptop_failed(error) = { error: "#{owner}'s laptop: #{error.message}" }
      end
      chat.with_mcp(laptop.new(owner: 'Ada'))
      allow(chat.provider).to receive(:complete).and_return(calls('read_notes'), answer)

      chat.ask('Read my notes')

      expect(results).to eq(['{"error":"Ada\'s laptop: Asleep"}'])
    end

    def mcp_result_of(mcp)
      chat.with_mcp(mcp)
      allow(chat.provider).to receive(:complete).and_return(calls('read_notes'), answer)
      chat.ask('Read my notes')
      results.sole
    end

    it 'gives MCP subclasses the handlers of their parent, even after the subclass is defined' do
      parent = laptop_class
      child = Class.new(parent) { self.default_name = 'laptop' }
      parent.rescue_from(RubyLLM::MCP::Error) { 'from the parent' }

      expect(mcp_result_of(child.new(owner: 'Ada'))).to eq('from the parent')
    end

    it 'falls back to handlers declared on MCP::Tool' do
      RubyLLM::MCP::Tool.rescue_from(RubyLLM::MCP::Error) { |error| "#{name}: #{error.message}" }

      expect(mcp_result_of(laptop_class.new(owner: 'Ada'))).to eq('read_notes: Asleep')
    end

    it 'prefers the MCP class handler to the MCP::Tool one' do
      RubyLLM::MCP::Tool.rescue_from(RubyLLM::MCP::Error) { 'from the tool class' }
      laptop = laptop_class { rescue_from(RubyLLM::MCP::Error) { 'from the server' } }

      expect(mcp_result_of(laptop.new(owner: 'Ada'))).to eq('from the server')
    end

    it 'sends the server the model arguments, without the tool call' do
      laptop = laptop_class { rescue_from(RubyLLM::MCP::Error) { 'handled' } }.new(owner: 'Ada')
      chat.with_mcp(laptop)
      allow(chat.provider).to receive(:complete).and_return(calls('read_notes', arguments: { 'day' => 'today' }),
                                                            answer)

      chat.ask('Read my notes')

      expect(laptop.class.transport.calls.map { |params| params[:arguments] }).to eq([{ day: 'today' }])
    end

    it 'leaves a call you make yourself to you' do
      tool = laptop_class { rescue_from(RubyLLM::MCP::Error) { 'swallowed' } }.new(owner: 'Ada').tools.first

      expect { tool.call }.to raise_error(RubyLLM::MCP::Error, /Asleep/)
    end
  end

  describe 'code execution' do
    let(:context) { RubyLLM.context { |config| config.sandbox = FakeSandbox.new { raise 'the sandbox broke' } } }
    let(:chat) { context.chat(model: model_for(:openai), provider: :openai).with_code_execution }

    around do |example|
      saved = [RubyLLM::CodeExecution, described_class].to_h { |klass| [klass, klass.rescue_handlers.dup] }
      example.run
    ensure
      saved.each { |klass, handlers| klass.instance_variable_set(:@rescue_handlers, handlers) }
    end

    def run_code
      allow(chat.provider).to receive(:complete)
        .and_return(calls('run_code', arguments: { 'language' => 'ruby', 'code' => 'puts 1' }), answer)
      chat.ask('Run it')
      results.sole
    end

    it 'runs a handler declared on CodeExecution' do
      RubyLLM::CodeExecution.rescue_from(RuntimeError) { |error| { error: "The sandbox failed: #{error.message}" } }

      expect(run_code).to eq('{"error":"The sandbox failed: the sandbox broke"}')
    end

    it 'runs a handler declared on Tool after CodeExecution is defined' do
      described_class.rescue_from(RuntimeError) { 'from every tool' }

      expect(run_code).to eq('from every tool')
    end

    it 'raises without a handler, as before' do
      expect { run_code }.to raise_error(RuntimeError, 'the sandbox broke')
    end
  end
end
