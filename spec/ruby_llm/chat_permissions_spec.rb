# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:search) { tool_class('search', reads: true) }
  let(:edit) { tool_class('edit') }
  let(:refund) { tool_class('refund', approval: true) }
  let(:lookup) { tool_class('lookup', reads: true, approval: true) }

  def tool_class(name, reads: false, approval: false)
    runs = executions
    Class.new(RubyLLM::Tool) do
      read_only if reads
      requires_approval if approval
      define_singleton_method(:tool_name) { name }
      define_method(:execute) do
        runs << name.to_sym
        "#{name} done"
      end
    end
  end

  def tool_call_message(*names)
    @call_count ||= 0
    calls = names.to_h do |name|
      id = "call_#{@call_count += 1}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls)
  end

  def stubbed_chat(*responses, tools: [search, edit, refund, lookup])
    chat = RubyLLM.chat.with_tools(*tools)
    allow(chat.provider).to receive(:complete).and_return(*responses, RubyLLM::Message.new(role: :assistant,
                                                                                           content: 'All done'))
    chat
  end

  def result_for(chat, id)
    chat.messages.find { |message| message.tool_call_id == id }&.content
  end

  describe '#with_permissions' do
    it 'sets the mode, returns self, and resets with nil' do
      chat = RubyLLM.chat

      expect(chat.permissions).to be_nil
      expect(chat.with_permissions(:ask)).to be(chat)
      expect(chat.permissions).to eq(:ask)
      expect(chat.with_permissions('read_only').permissions).to eq(:read_only)
      expect(chat.with_permissions(nil).permissions).to be_nil
    end

    it 'rejects unknown modes and allow: outside :auto' do
      chat = RubyLLM.chat

      expect { chat.with_permissions(:yolo) }.to raise_error(ArgumentError, /permissions must be/)
      expect { chat.with_permissions(:ask, allow: [search]) }.to raise_error(ArgumentError, /applies to :auto/)
      expect { chat.with_permissions(:auto, allow: [42]) }.to raise_error(ArgumentError, /allow: takes/)
      expect { chat.with_permissions(:auto, allow: [{ disk: ['/'] }]) }.to raise_error(ArgumentError, /grants/)
      expect { chat.with_permissions(:auto, allow: [String]) }.to raise_error(ArgumentError, /Tool and MCP/)
    end
  end

  describe 'without a mode' do
    it 'runs tools unless they require approval, as before' do
      chat = stubbed_chat(tool_call_message('search', 'edit', 'refund'))

      chat.ask('Go')

      expect(executions).to eq(%i[search edit])
      expect(chat.pending_approvals.map(&:name)).to eq(['refund'])
    end
  end

  describe ':read_only' do
    it 'runs read-only tools and denies the rest with a structured result' do
      chat = stubbed_chat(tool_call_message('search', 'edit', 'refund')).with_permissions(:read_only)

      response = chat.ask('Go')

      expect(executions).to eq([:search])
      expect(result_for(chat, 'call_2')).to include('edit tool call was not run', 'read-only')
      expect(result_for(chat, 'call_3')).to include('error')
      expect(response.content).to eq('All done')
    end

    it 'still asks before a read-only tool that requires approval' do
      chat = stubbed_chat(tool_call_message('lookup')).with_permissions(:read_only)

      chat.ask('Go')

      expect(chat).to be_awaiting_approval
      expect(chat.pending_approvals.map(&:name)).to eq(['lookup'])
    end

    it 'denies even a call approved before the mode changed' do
      chat = stubbed_chat(tool_call_message('edit')).with_permissions(:ask)
      chat.ask('Go')
      chat.approve('call_1').with_permissions(:read_only)

      chat.complete

      expect(executions).to be_empty
      expect(result_for(chat, 'call_1')).to include('read-only')
    end
  end

  describe ':ask' do
    it 'runs read-only tools and parks every other call like an approval' do
      chat = stubbed_chat(tool_call_message('search', 'edit', 'refund')).with_permissions(:ask)

      chat.ask('Go')

      expect(executions).to eq([:search])
      expect(chat).to be_awaiting_approval
      expect(chat).to be_waiting
      expect(chat.pending_approvals.map(&:name)).to eq(%w[edit refund])
    end

    it 'runs approved calls and denies denied ones' do
      chat = stubbed_chat(tool_call_message('edit', 'refund')).with_permissions(:ask)
      chat.ask('Go')

      chat.approve('call_1').deny('call_2')
      response = chat.complete

      expect(executions).to eq([:edit])
      expect(result_for(chat, 'call_2')).to include('The user denied the refund tool call')
      expect(response.content).to eq('All done')
    end

    it 'remembers an approved tool for the rest of the chat' do
      chat = stubbed_chat(tool_call_message('edit'), tool_call_message('edit', 'refund')).with_permissions(:ask)
      chat.ask('Go')

      chat.approve(chat.pending_approvals.first, remember: true)
      chat.complete

      expect(executions).to eq(%i[edit edit])
      expect(chat.pending_approvals.map(&:name)).to eq(['refund'])
    end

    it 'remembers by tool call id too' do
      chat = stubbed_chat(tool_call_message('refund'), tool_call_message('refund')).with_permissions(:ask)
      chat.ask('Go')

      chat.approve('call_1', remember: true).complete

      expect(executions).to eq(%i[refund refund])
      expect { chat.approve('missing', remember: true) }.to raise_error(ArgumentError, /Unknown tool call/)
    end

    it 'remembers approvals without a mode as well' do
      chat = stubbed_chat(tool_call_message('refund'), tool_call_message('refund'))
      chat.ask('Go')

      chat.approve('call_1', remember: true).complete

      expect(executions).to eq(%i[refund refund])
    end
  end

  describe ':auto' do
    it 'runs read-only and allowed tools and parks the rest' do
      chat = stubbed_chat(tool_call_message('search', 'edit', 'refund'), tools: [search, edit, refund, lookup,
                                                                                 tool_class('publish')])
      chat.with_permissions(:auto, allow: [edit, 'publish'])

      chat.ask('Go')

      expect(executions).to eq(%i[search edit])
      expect(chat.pending_approvals.map(&:name)).to eq(['refund'])
    end

    it 'accepts tool names, Tool instances, and nested lists' do
      chat = stubbed_chat(tool_call_message('edit', 'publish'), tools: [edit, tool_class('publish')])
      chat.with_permissions(:auto, allow: [[edit.new], :publish])

      chat.ask('Go')

      expect(executions).to eq(%i[edit publish])
    end

    it 'never skips a tool that requires approval, even when allowed' do
      chat = stubbed_chat(tool_call_message('refund')).with_permissions(:auto, allow: [refund])

      chat.ask('Go')

      expect(chat.pending_approvals.map(&:name)).to eq(['refund'])
    end

    it 'runs every tool of an allowed MCP server' do
      server = Class.new(RubyLLM::MCP) do
        def self.default_name = 'docs'
      end
      mcp_tool = RubyLLM::MCP::Tool.new(server.allocate, { 'name' => 'write_page' })
      instance = server.allocate
      allow(instance).to receive_messages(name: 'docs', tools: [mcp_tool])
      chat = stubbed_chat(tool_call_message('write_page'), tools: [])
      allow(chat).to receive_messages(mcp: [instance], tools: { write_page: mcp_tool })
      allow(mcp_tool).to receive(:call).and_return('written')

      chat.with_permissions(:auto, allow: [server]).ask('Go')

      expect(result_for(chat, 'call_1')).to eq('written')
    end
  end

  describe ':dangerous' do
    it 'runs every tool, including those that require approval' do
      chat = stubbed_chat(tool_call_message('edit', 'refund')).with_permissions(:dangerous)

      chat.ask('Go')

      expect(executions).to eq(%i[edit refund])
      expect(chat).not_to be_waiting
    end

    it 'keeps a recorded denial' do
      chat = stubbed_chat(tool_call_message('edit', 'refund')).with_permissions(:ask)
      chat.ask('Go')

      chat.deny('call_2').with_permissions(:dangerous).complete

      expect(executions).to eq([:edit])
      expect(result_for(chat, 'call_2')).to include('denied')
    end
  end

  it 'decides calls already waiting under the mode set mid-chat' do
    chat = stubbed_chat(tool_call_message('edit')).with_permissions(:ask)
    chat.ask('Go')
    expect(chat).to be_awaiting_approval

    chat.with_permissions(:auto, allow: [edit])

    expect(chat).not_to be_waiting
    expect(chat.pending_approvals).to be_empty
    chat.complete
    expect(executions).to eq([:edit])
  end

  describe 'MCP tools' do
    it 'count as read-only when the server marks them readOnlyHint' do
      mcp = instance_double(RubyLLM::MCP)
      reader = RubyLLM::MCP::Tool.new(mcp, { 'name' => 'list', 'annotations' => { 'readOnlyHint' => true } })
      writer = RubyLLM::MCP::Tool.new(mcp, { 'name' => 'write' })

      expect(reader).to be_read_only
      expect(writer).not_to be_read_only
    end
  end

  describe 'provider-executed tool calls' do
    def remote_call(name)
      RubyLLM::ToolCall.new(id: 'call_1', name:, arguments: {}, remote: true)
    end

    def parked(chat, name)
      chat.add_message(role: :assistant, content: '', tool_calls: { 'call_1' => remote_call(name) })
      chat
    end

    it 'wait in :ask, run when allowed in :auto, and are refused in :read_only' do
      chat = parked(RubyLLM.chat, 'deploy')

      expect(chat.with_permissions(:ask).pending_approvals.map(&:name)).to eq(['deploy'])
      expect(chat.with_permissions(:auto, allow: ['deploy']).pending_approvals).to be_empty
      expect(chat.with_permissions(:dangerous).pending_approvals).to be_empty
      expect(chat.with_permissions(:read_only).pending_approvals).to be_empty
      expect(chat.send(:remote_permission_decision, remote_call('deploy'))).to be(false)
    end

    it 'can be remembered by name' do
      chat = parked(RubyLLM.chat, 'deploy').with_permissions(:ask)

      chat.approve('call_1', remember: true)
      chat.add_message(role: :assistant, content: '',
                       tool_calls: { 'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'deploy', arguments: {},
                                                                       remote: true) })

      expect(chat.pending_approvals).to be_empty
    end
  end
end
