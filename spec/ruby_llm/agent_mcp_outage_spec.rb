# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }
  let(:requests) { [] }
  let(:down) do
    seen = requests
    transport = Class.new do
      define_method(:request) do |message, **|
        seen << message[:method]
        raise RubyLLM::MCP::Error.new('down', response: Faraday::Response.new(status: 503))
      end
      define_method(:notify) { |*, **| nil }
      define_method(:cancel) { |*, **| nil }
      define_method(:close) { nil }
    end
    stub_const('Linear', Class.new(RubyLLM::MCP) do
      transport { transport.new }
      requires_approval
    end)
  end
  let(:agent) do
    server = down
    Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature)
      mcp server
      code_execution
    end
  end

  around do |example|
    original = RubyLLM.config.sandbox
    RubyLLM.config.sandbox = FakeSandbox.new
    RubyLLM::MCP::Outages.clear
    example.run
  ensure
    RubyLLM.config.sandbox = original
    RubyLLM::MCP::Outages.clear
  end

  def parked_chat
    fixture = [RbConfig.ruby, File.expand_path('../fixtures/mcp/server.rb', __dir__)]
    reachable = Class.new(RubyLLM::MCP) do
      command(*fixture)
      requires_approval
    end.new
    chat = agent.create!
    names = { "#{call_id}_1" => 'delete_everything', "#{call_id}_2" => 'echo' }
    tool_calls = names.to_h { |id, name| [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})] }
    Chat.find(chat.id).with_mcp(reachable)
        .add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
    chat
  ensure
    reachable&.close
  end

  it 'builds, creates, and finds chats without contacting their MCP servers' do
    agent.new
    chat = agent.create!
    agent.find(chat.id)

    expect(requests).to be_empty
  end

  it 'builds a chat whose tool choice names a tool of an MCP server that is down' do
    server = down
    chooser = Class.new(described_class) do
      chat_class Chat
      model model_for(:openai, :temperature)
      mcp server
      tool_options choice: :search_issues
    end

    chooser.find(chooser.create!.id)

    expect(requests).to be_empty
  end

  it 'shows and settles the questions of a chat whose MCP servers are down' do
    chat = parked_chat
    first, second = agent.find(chat.id).pending_questions.map(&:id)

    agent.find(chat.id).answer(first)
    agent.find(chat.id).decline(second, 'Not now')

    approvals = RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: [first, second])
                                               .order(:tool_call_id).pluck(:approval)
    expect(approvals).to eq(%w[approved denied])
    expect(agent.find(chat.id).pending_questions).to be_empty
    expect(requests).to be_empty
  end

  it 'approves the call of a chat whose MCP servers are down' do
    chat = parked_chat

    agent.find(chat.id).approve("#{call_id}_1")

    expect(agent.find(chat.id).pending_questions.map(&:id)).to eq(["#{call_id}_2"])
    expect(requests).to be_empty
  end

  it 'reads what the chat page shows while its MCP servers are down' do
    chat = agent.find(parked_chat.id)

    expect(chat.running?).to be(false)
    expect(chat.tools[:run_code]).to be_a(RubyLLM::CodeExecution)
    expect(chat.pending_questions.size).to eq(2)
  end
end
