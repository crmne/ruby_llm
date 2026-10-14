# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:cache_dir) { Dir.mktmpdir('ruby_llm-packages-spec') }
  let(:sandbox) { FakeSandbox.new }
  let(:executions) { [] }
  let(:edit_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'edit' }
      define_method(:execute) do
        runs << :edit
        'edited'
      end
    end
  end

  around do |example|
    sandbox_before = RubyLLM.config.sandbox
    cache_before = RubyLLM.config.package_cache_dir
    RubyLLM.config.sandbox = sandbox
    RubyLLM.config.package_cache_dir = cache_dir
    example.run
  ensure
    RubyLLM.config.sandbox = sandbox_before
    RubyLLM.config.package_cache_dir = cache_before
    FileUtils.rm_rf(cache_dir)
  end

  def tool_call(name, arguments = {}, id: "call_#{SecureRandom.hex(4)}")
    RubyLLM::ToolCall.new(id:, name:, arguments:)
  end

  def park(chat, call)
    chat.add_message(RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }))
    call
  end

  def process(chat, &)
    Chat.find(chat.id).with_tools(edit_tool).with_code_execution.tap do |record|
      record.instance_exec(&) if block_given?
    end
  end

  def finish_with(record, *responses)
    allow(record.to_llm.provider).to receive(:complete)
      .and_return(*responses, RubyLLM::Message.new(role: :assistant, content: 'Done'))
  end

  def network_request(*hosts)
    tool_call('request_permission', { 'permission' => 'network', 'targets' => hosts, 'reason' => 'Install' })
  end

  it 'persists the mode so another process decides under it' do
    chat = Chat.create!(model: model_for(:openai)).with_permissions(:ask)

    expect(chat.reload[:permissions]).to eq('ask')
    expect(Chat.find(chat.id).permissions).to eq(:ask)
    expect(chat.with_permissions(nil).permissions).to be_nil
    expect(Chat.find(chat.id)[:permissions]).to be_nil
  end

  it 'persists the mode of an unsaved chat when it is saved' do
    chat = Chat.new(model: model_for(:openai)).with_permissions(:read_only)
    chat.save!

    expect(Chat.find(chat.id).permissions).to eq(:read_only)
  end

  it 'reads a mode changed in another process outside the query cache' do
    chat = Chat.create!(model: model_for(:openai)).with_tools(edit_tool).with_permissions(:ask)
    park(chat, tool_call('edit'))

    ActiveRecord::Base.cache do
      expect(chat).to be_awaiting_approval
      Chat.find(chat.id).with_permissions(:dangerous)
      expect(chat).not_to be_awaiting_approval
    end
  end

  it 'remembers an approval for every process' do
    chat = Chat.create!(model: model_for(:openai)).with_tools(edit_tool).with_permissions(:ask)
    first = park(chat, tool_call('edit'))

    chat.approve(first.id, remember: true)

    expect(Chat.find(chat.id)[:permission_grants]).to include('tools' => ['edit'])
    later = process(chat)
    park(later, tool_call('edit'))
    expect(later.pending_approvals).to be_empty
  end

  it 'approves a request for access in one process and resumes in another' do
    chat = Chat.create!(model: model_for(:openai)).with_code_execution.with_permissions(:ask)
    request = park(chat, network_request('pypi.org'))
    expect(chat.pending_approvals.map(&:tool_call_id)).to eq([request.id])

    Chat.find(chat.id).approve(request.id)

    job = process(chat)
    code = tool_call('run_code', { 'language' => 'shell', 'code' => 'pip install requests' })
    finish_with(job, RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { code.id => code }))
    job.complete

    grants = Chat.find(chat.id)[:permission_grants]
    expect(grants['network']).to eq(['pypi.org'])
    expect(grants['environment']).to match(/\A\h{8}-/)
    expect(sandbox.code_runs.last[:network]).to eq(allow: ['pypi.org'])
    expect(sandbox.code_runs.last[:writable]).to include(File.join(cache_dir, 'chats', grants['environment']))
  end

  it 'merges grants recorded by different processes' do
    chat = Chat.create!(model: model_for(:openai)).with_code_execution.with_permissions(:dangerous)

    process(chat).to_llm.tools[:request_permission].call(permission: 'network', targets: ['pypi.org'], reason: 'x')
    process(chat).to_llm.tools[:request_permission].call(permission: 'network', targets: ['rubygems.org'],
                                                         reason: 'x')

    expect(Chat.find(chat.id)[:permission_grants]['network']).to eq(%w[pypi.org rubygems.org])
  end

  describe 'agents' do
    let(:agent) do
      stub_const('PermissionsAgent', Class.new(RubyLLM::Agent) do
        chat_model Chat
        model model_for(:openai)
        permissions :auto, allow: ['edit']
      end)
    end

    it 'sets the starting mode on create and restores the persisted one on find' do
      chat = agent.create!

      expect(chat.permissions).to eq(:auto)
      chat.with_permissions(:ask)
      found = agent.find(chat.id)
      expect(found.permissions).to eq(:ask)
      expect(Chat.find(chat.id)[:permissions]).to eq('ask')
    end

    it 'applies its allow: list to a persisted :auto chat' do
      chat = agent.create!
      found = agent.find(chat.id).with_tools(edit_tool)
      park(found, tool_call('edit'))

      expect(found.pending_approvals).to be_empty
    end
  end

  context 'without the permission columns' do
    def without_permission_columns
      connection = ActiveRecord::Base.connection
      ActiveRecord::Base.transaction do
        connection.remove_column(:chats, :permissions)
        connection.remove_column(:chats, :permission_grants)
        Chat.reset_column_information
        yield
        raise ActiveRecord::Rollback
      end
    ensure
      Chat.reset_column_information
    end

    it 'keeps the mode and grants in memory' do
      without_permission_columns do
        chat = Chat.create!(model: model_for(:openai)).with_tools(edit_tool).with_permissions(:ask)
        call = park(chat, tool_call('edit'))

        expect(chat.permissions).to eq(:ask)
        expect(chat.pending_approvals.map(&:tool_call_id)).to eq([call.id])
        chat.approve(call.id, remember: true)
        park(chat, tool_call('edit'))
        expect(chat.pending_approvals).to be_empty
        expect(Chat.find(chat.id).permissions).to be_nil
      end
    end
  end
end
