# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:files_class) do
    command = [RbConfig.ruby, File.expand_path('../fixtures/mcp/server.rb', __dir__)]
    Class.new(RubyLLM::MCP) { command(*command) }
  end
  let(:files) { files_class.new }
  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  before { stub_const('Files', files_class) }
  after { files.close }

  def tool_call(name, arguments)
    RubyLLM::Message.new(role: :assistant, content: '',
                         tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name:, arguments:) })
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'Done', model: model_for(:anthropic), input_tokens: 1,
                         output_tokens: 1)
  end

  it 'reads connected servers by name' do
    chat.with_mcp(files)

    expect(chat.mcp.files).to be(files)
    expect(chat.mcp[:files]).to be(files)
    expect(chat.mcp.to_a).to eq([files])
  end

  it 'accepts MCP classes' do
    chat.with_mcp(Files)

    expect(chat.mcp.files).to be_a(Files)
  end

  it 'waits to contact servers until the chat needs their tools' do
    allow(files).to receive(:tools).and_call_original

    chat.with_mcp(files)

    expect(files).not_to have_received(:tools)
    expect(chat.tools.keys).to include(:echo, :add)
  end

  it 'lets the model call server tools' do
    allow(chat.provider).to receive(:complete).and_return(tool_call('add', { 'a' => 2, 'b' => 3 }), answer)

    chat.with_mcp(files).ask('What is 2 + 3?')

    expect(chat.messages.find { |message| message.role == :tool }.content).to eq('5')
  end

  it 'pauses server tools that need approval' do
    files_class.requires_approval :add
    allow(chat.provider).to receive(:complete).and_return(tool_call('add', { 'a' => 2, 'b' => 3 }), answer)

    chat.with_mcp(files).ask('What is 2 + 3?')

    expect(chat).to be_awaiting_approval
    chat.approve(chat.pending_approvals.first).complete
    expect(chat.messages.find { |message| message.role == :tool }.content).to eq('5')
  end

  it 'refuses two tools with the same name' do
    echo = Class.new(RubyLLM::Tool) do
      def self.tool_name = 'echo'
      def execute(text:) = text
    end

    chat.with_tools(echo).with_mcp(files)

    expect { chat.tools }.to raise_error(ArgumentError, /Two tools are named echo/)
  end

  it 'disconnects servers with nil' do
    chat.with_mcp(files).with_mcp(nil)

    expect(chat.mcp).to be_empty
    expect(chat.tools).to be_empty
  end

  it 'connects servers declared on an agent' do
    model_id = model_for(:anthropic)
    agent = Class.new(RubyLLM::Agent) do
      model model_id
      inputs :server
      mcp { server }
    end

    expect(agent.chat(server: files).mcp.files).to be(files)
  end
end
