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

  it 'asks with a server prompt' do
    allow(chat.provider).to receive(:complete).and_return(answer)

    chat.ask(files.prompt(:code_review, code: 'puts 1'))

    expect(chat.messages.map(&:role)).to eq(%i[user assistant user assistant])
    expect(chat.messages[2].content).to eq('Security.')
  end

  it 'attaches server resources' do
    allow(chat.provider).to receive(:complete).and_return(answer)

    chat.ask('Describe this', with: files.resources.last)

    expect(chat.messages.first.attachments.first).to have_attributes(filename: 'pixel.png', mime_type: 'image/png')
  end

  it 'stops a server tool when the chat is cancelled' do
    allow(chat.provider).to receive(:complete).and_return(tool_call('wait', {}), answer)
    chat.with_mcp(files).before_tool_call do
      Thread.new do
        sleep 0.2
        chat.cancel
      end
    end

    expect { chat.ask('Wait for it') }.to raise_error(RubyLLM::CancelledError)
  end

  describe 'input requests' do
    before { allow(chat.provider).to receive(:complete).and_return(tool_call('deploy', {}), answer) }

    it 'pauses the tool call until the user answers' do
      chat.with_mcp(files).ask('Deploy')

      expect(chat).to be_awaiting_input
      request = chat.pending_inputs.first
      expect(request).to have_attributes(message: 'Which environment?', tool_call: have_attributes(name: 'deploy'))

      chat.answer(request, environment: 'production').complete

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deployed to production')
      expect(chat).not_to be_awaiting_input
    end

    it 'resumes a declined request' do
      chat.with_mcp(files).ask('Deploy')
      chat.decline(chat.pending_inputs.first).complete

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deploy cancelled')
    end

    it 'does not pause when a callback answers' do
      files_class.before_input_request { |request| request.answer(environment: 'staging') }

      chat.with_mcp(files).ask('Deploy')

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deployed to staging')
    end

    it 'waits on approvals and inputs together' do
      files_class.requires_approval :add
      allow(chat.provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: {
                               'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'deploy', arguments: {}),
                               'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'add',
                                                                 arguments: { 'a' => 1, 'b' => 1 })
                             }),
        answer
      )

      chat.with_mcp(files).ask('Deploy and add')

      expect(chat).to be_awaiting_input
      expect(chat).to be_awaiting_approval
      expect { chat.ask_later('Next') }.to raise_error(RubyLLM::PendingToolCallsError, /answering pending inputs/)
    end
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
