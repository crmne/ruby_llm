# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:search) do
    stub_const('SearchDocs', Class.new(RubyLLM::Tool) do
      read_only
      def execute = 'found'
    end)
  end

  def agent_with(&)
    Class.new(described_class) do
      model model_for(:openai), provider: :openai
      class_exec(&)
    end
  end

  it 'sets the starting mode of the chats it builds' do
    expect(agent_with { permissions :ask }.chat.permissions).to eq(:ask)
    expect(agent_with { permissions :ask }.permissions).to eq(:ask)
    expect(agent_with { temperature 0.1 }.chat.permissions).to be_nil
  end

  it 'passes allow: in :auto' do
    tool = search
    chat = agent_with { permissions :auto, allow: [tool, { network: ['pypi.org'] }] }.chat

    expect(chat.permissions).to eq(:auto)
    expect(chat.instance_variable_get(:@permission_allow)).to include(tools: ['search_docs'], network: ['pypi.org'])
  end

  it 'is inherited and can be overridden' do
    parent = agent_with { permissions :read_only }

    expect(Class.new(parent).chat.permissions).to eq(:read_only)
    expect(Class.new(parent) { permissions :dangerous }.chat.permissions).to eq(:dangerous)
  end

  it 'keeps the mode of a chat that already has one' do
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai).with_permissions(:read_only)

    agent = agent_with { permissions :auto, allow: ['search_docs'] }.new(chat:)

    expect(agent.permissions).to eq(:read_only)
  end

  it 'rejects invalid declarations' do
    expect { agent_with { permissions :yolo } }.to raise_error(ArgumentError, /permissions must be/)
    expect { agent_with { permissions :ask, allow: ['x'] } }.to raise_error(ArgumentError, /applies to :auto/)
  end

  it 'delegates with_permissions, permissions, and approve with remember:' do
    agent = agent_with { temperature 0.1 }.new

    expect(agent.with_permissions(:ask)).to be(agent.chat)
    expect(agent.permissions).to eq(:ask)
    agent.chat.add_message(role: :assistant, content: '',
                           tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'x', arguments: {}) })
    expect(agent.approve('call_1', remember: true)).to be(agent.chat)
  end
end
