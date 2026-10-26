# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  let(:call_id) { "call_#{SecureRandom.hex(6)}" }

  let(:approval_tool) do
    Class.new(RubyLLM::Tool) do
      requires_approval

      define_method(:name) { 'dangerous' }
      define_method(:execute) { 'done' }
    end
  end

  def parked_chat
    chat = Chat.create!(model: 'gpt-4.1-nano')
    chat.with_tools(approval_tool)
    chat.add_message(
      RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: { call_id => RubyLLM::ToolCall.new(id: call_id, name: 'dangerous', arguments: {}) }
      )
    )
    chat
  end

  it 'returns the persisted tool call records awaiting a decision' do
    chat = parked_chat

    records = chat.pending_approvals
    expect(records.map(&:tool_call_id)).to eq([call_id])
    expect(records.first).to be_a(RubyLLM::ActiveRecord::ToolCall)
    expect(chat).to be_awaiting_approval
    expect(chat).to be_waiting
  end

  it 'persists an approval recorded from a pending record' do
    chat = parked_chat

    chat.approve(chat.pending_approvals.first)

    expect(chat.pending_approvals).to be_empty
    expect(chat).not_to be_awaiting_approval
    expect(chat).not_to be_waiting
    expect(RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).approval).to eq('approved')
  end

  it 'reads a decision persisted by another process' do
    chat = parked_chat
    RubyLLM::ActiveRecord::ToolCall.find_by(tool_call_id: call_id).update!(approval: 'denied')

    reloaded = Chat.find(chat.id)
    reloaded.with_tools(approval_tool)

    expect(reloaded).not_to be_awaiting_approval
    expect(reloaded.pending_approvals).to be_empty
  end

  it 'refuses to persist a new question while the round is parked' do
    chat = parked_chat

    expect { chat.ask_later('Write an essay instead') }.to raise_error(RubyLLM::PendingToolCallsError)
    expect(chat.messages_association.where(role: 'user')).to be_empty
  end

  it 'reloads parallel calls in the order the model made them' do
    ids = [call_id, "call_#{SecureRandom.hex(6)}"]
    chat = Chat.create!(model: 'gpt-4.1-nano')
    chat.add_message(
      RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: ids.to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'dangerous', arguments: {})] }
      )
    )
    chat.approve(call_id)

    calls = reading_rows_in_reverse { Chat.find(chat.id).to_llm.messages.last.tool_calls.keys }

    expect(calls).to eq(ids)
  end

  it 'returns pending approvals in the order the model made them' do
    ids = ["#{call_id}_1", "#{call_id}_2"]
    chat = Chat.create!(model: 'gpt-4.1-nano')
    chat.with_tools(approval_tool)
    chat.add_message(
      RubyLLM::Message.new(
        role: :assistant,
        content: '',
        tool_calls: ids.to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'dangerous', arguments: {})] }
      )
    )

    reloaded = reading_rows_in_reverse { Chat.find(chat.id).pending_approvals.map(&:tool_call_id) }

    expect(reloaded).to eq(ids)
  end

  describe 'with an MCP server whose tools decide approval' do
    let(:server_class) do
      command = [RbConfig.ruby, File.expand_path('../../fixtures/mcp/server.rb', __dir__)]
      Class.new(RubyLLM::MCP) do
        command(*command)
        requires_approval if: :destructive?
      end
    end
    let(:server) { server_class.new }
    let(:agent) do
      mcp_server = server_class
      Class.new(RubyLLM::Agent) do
        chat_model Chat
        model 'gpt-4.1-nano'
        mcp { [mcp_server] }
      end
    end

    after { server.close }

    def park_mcp_calls
      chat = Chat.create!(model: 'gpt-4.1-nano').with_mcp(server)
      calls = { "#{call_id}_1" => 'delete_everything', "#{call_id}_2" => 'echo' }
      tool_calls = calls.to_h { |id, name| [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})] }
      chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls:))
      chat
    end

    it 'reads pending approvals from the database without connecting to the server' do
      chat = park_mcp_calls
      allow(RubyLLM::MCP::Stdio).to receive(:new).and_call_original

      pending = agent.find(chat.id).pending_approvals.map(&:tool_call_id)

      expect(pending).to eq(["#{call_id}_1"])
      expect(RubyLLM::MCP::Stdio).not_to have_received(:new)
    end

    it 'records the decision the live tool made when the call was persisted' do
      park_mcp_calls

      approvals = RubyLLM::ActiveRecord::ToolCall.where(tool_call_id: ["#{call_id}_1", "#{call_id}_2"])
                                                 .order(:tool_call_id).pluck(:approval)
      expect(approvals).to eq(['pending', nil])
    end
  end

  # SQLite returns the rows of a query without ORDER BY in reverse under
  # this pragma, as PostgreSQL returns a row after an update moves it.
  def reading_rows_in_reverse
    connection = RubyLLM::ActiveRecord::ToolCall.connection
    connection.execute('PRAGMA reverse_unordered_selects = ON')
    yield
  ensure
    connection.execute('PRAGMA reverse_unordered_selects = OFF')
  end
end
