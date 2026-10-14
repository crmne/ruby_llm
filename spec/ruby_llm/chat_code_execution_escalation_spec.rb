# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:default_sandbox) { FakeSandbox.new }
  let(:workspace) { File.realpath(Dir.mktmpdir('ruby_llm-workspace')) }
  let(:workspace_sandbox) do
    stub_const('WorkspaceSandbox', Class.new(FakeSandbox))
    WorkspaceSandbox.new(directory: workspace, writable: [workspace], timeout: 300)
  end
  let(:online_sandbox) do
    stub_const('OnlineSandbox', Class.new(FakeSandbox))
    OnlineSandbox.new(network: true)
  end
  let(:chat) do
    RubyLLM.context { |config| config.sandbox = default_sandbox }
           .chat(model: model_for(:openai), provider: :openai)
           .with_code_execution(escalate_to: [workspace_sandbox, online_sandbox])
  end

  after { FileUtils.rm_rf(workspace) }

  def tool
    chat.tools[:run_code]
  end

  def code_call(id, code: 'puts 1', sandbox: nil, reason: nil)
    RubyLLM::ToolCall.new(id:, name: 'run_code',
                          arguments: { 'language' => 'ruby', 'code' => code, 'sandbox' => sandbox, 'reason' => reason })
  end

  def model_calls(*calls)
    chat.add_message(role: :user, content: 'Go')
    chat.add_message(role: :assistant, content: '', tool_calls: calls.to_h { |call| [call.id, call] })
    allow(chat.provider).to receive(:complete).and_return(RubyLLM::Message.new(role: :assistant, content: 'Done'))
  end

  def result_for(call)
    chat.messages.find { |message| message.tool_call_id == call.id }&.content
  end

  describe 'the run_code arguments' do
    it 'offers no sandbox argument without escalate_to' do
      plain = RubyLLM.context { |config| config.sandbox = default_sandbox }
                     .chat(model: model_for(:openai), provider: :openai).with_code_execution

      expect(plain.tools[:run_code].parameters_schema['properties'].keys).to eq(%w[language code])
      expect(plain.tools[:run_code].description).not_to include('set sandbox')
    end

    it 'names the sandboxes the model may ask for after their classes, nullable for strict mode' do
      schema = tool.parameters_schema

      expect(tool.escalations).to eq(%w[workspace online])
      expect(schema['required']).to eq(%w[language code sandbox reason])
      expect(schema.dig('properties', 'sandbox')).to include('type' => %w[string null],
                                                             'enum' => ['workspace', 'online', nil])
      expect(schema.dig('properties', 'reason', 'type')).to eq(%w[string null])
    end

    it 'describes each sandbox from its settings' do
      expect(tool.summary('workspace')).to eq("Starts in #{workspace}. Can change #{workspace}. " \
                                              'No network access. Stops after 300 seconds.')
      expect(tool.summary(:online)).to eq('Can reach the network. Stops after 120 seconds.')
      expect(tool.summary('root')).to be_nil
      expect(tool.description).to include('The user approves each such call, and the next call runs in the ' \
                                          'default sandbox again.')
      expect(tool.description).to include("workspace: Code starts in #{workspace}, not in the run directory")
    end

    it 'takes names from a Hash and refuses unnamed, duplicate, and malformed names' do
      named = chat.with_code_execution(escalate_to: { files: workspace_sandbox }).tools[:run_code]

      expect(named.escalations).to eq(['files'])
      expect { chat.with_code_execution(escalate_to: [Class.new(FakeSandbox).new]) }
        .to raise_error(ArgumentError, /Name the sandbox/)
      expect { chat.with_code_execution(escalate_to: [workspace_sandbox, WorkspaceSandbox.new]) }
        .to raise_error(ArgumentError, /Two sandboxes are named workspace/)
      expect { chat.with_code_execution(escalate_to: { 'Full Disk' => online_sandbox }) }
        .to raise_error(ArgumentError, /not a name like workspace/)
    end

    it 'leaves out sandboxes that cannot run on this machine' do
      stub_const('BrokenSandbox', Class.new(FakeSandbox))
      chat.with_code_execution(escalate_to: [workspace_sandbox, BrokenSandbox.new(supported: false)])

      expect(chat.tools[:run_code].escalations).to eq(['workspace'])
    end
  end

  describe 'escalation' do
    it 'runs a call without a sandbox in the default sandbox without asking' do
      call = code_call('call_1')
      model_calls(call)

      chat.complete

      expect(chat.awaiting_approval?).to be(false)
      expect(default_sandbox.code_runs.size).to eq(1)
      expect(workspace_sandbox.code_runs).to be_empty
    end

    it 'waits for approval, runs that one call in the named sandbox, and asks again next time' do
      first = code_call('call_1', sandbox: 'workspace', reason: 'Edit the project')
      model_calls(first)

      chat.complete
      expect(chat.pending_approvals.map(&:id)).to eq(['call_1'])
      expect(workspace_sandbox.code_runs).to be_empty

      chat.approve('call_1').complete
      expect(workspace_sandbox.code_runs.size).to eq(1)
      expect(workspace_sandbox.code_runs.last[:directory]).to be_nil

      second = code_call('call_2', sandbox: 'workspace')
      plain = code_call('call_3')
      chat.add_message(role: :assistant, content: '', tool_calls: { second.id => second, plain.id => plain })
      chat.complete

      expect(chat.pending_approvals.map(&:id)).to eq(['call_2'])
      expect(default_sandbox.code_runs.size).to eq(1)
      expect(workspace_sandbox.code_runs.size).to eq(1)
    end

    it 'never remembers an escalated call' do
      call = code_call('call_1', sandbox: 'online')
      model_calls(call)
      chat.complete

      expect { chat.approve('call_1', remember: true) }.to raise_error(ArgumentError, /cannot be remembered/)
      expect(chat.pending_approvals.map(&:id)).to eq(['call_1'])
    end

    it 'denies an escalated call without running it' do
      call = code_call('call_1', sandbox: 'online')
      model_calls(call)
      chat.complete

      chat.deny('call_1').complete

      expect(result_for(call)).to include('denied')
      expect(online_sandbox.code_runs).to be_empty
    end

    it 'tells the model about an unknown sandbox without running anything or asking' do
      call = code_call('call_1', sandbox: 'root')
      model_calls(call)

      chat.complete

      expect(chat.awaiting_approval?).to be(false)
      expect(result_for(call)).to include('Unknown sandbox root. Use one of: workspace, online')
      expect(default_sandbox.code_runs).to be_empty
    end

    it 'refuses an escalated run that reaches the tool without an approval for its call' do
      approved = code_call('call_1', sandbox: 'workspace')
      model_calls(approved)
      chat.approve('call_1')

      direct = tool.call(language: 'ruby', code: 'puts 1', sandbox: 'workspace')
      other_call = tool.call(language: 'ruby', code: 'puts 1', sandbox: 'workspace',
                             tool_call: code_call('call_9', sandbox: 'workspace'))
      changed_code = tool.call(language: 'ruby', code: 'system("rm -rf ~")', sandbox: 'workspace', tool_call: approved)
      other_sandbox = tool.call(language: 'ruby', code: 'puts 1', sandbox: 'online', tool_call: approved)

      expect([direct, other_call, changed_code])
        .to all(eq(error: 'Running in the workspace sandbox was not approved.'))
      expect(other_sandbox).to eq(error: 'Running in the online sandbox was not approved.')
      expect(workspace_sandbox.code_runs + online_sandbox.code_runs).to be_empty
    end

    it 'uses an approval once' do
      call = code_call('call_1', sandbox: 'workspace')
      model_calls(call)
      chat.approve('call_1')

      tool.call(language: 'ruby', code: 'puts 1', sandbox: 'workspace', tool_call: call)
      again = tool.call(language: 'ruby', code: 'puts 1', sandbox: 'workspace', tool_call: call)

      expect(again).to eq(error: 'Running in the workspace sandbox was not approved.')
      expect(workspace_sandbox.code_runs.size).to eq(1)
    end

    it 'keeps remembering ordinary tools' do
      lookup = Class.new(RubyLLM::Tool) do
        def self.tool_name = 'lookup'
        requires_approval
        def execute = 'found'
      end
      chat.with_tools(lookup)
      first = RubyLLM::ToolCall.new(id: 'call_1', name: 'lookup', arguments: {})
      model_calls(first)
      chat.complete
      chat.approve('call_1', remember: true).complete

      second = RubyLLM::ToolCall.new(id: 'call_2', name: 'lookup', arguments: {})
      chat.add_message(role: :assistant, content: '', tool_calls: { second.id => second })
      chat.complete

      expect(result_for(second)).to eq('found')
    end

    it 'reports the sandbox a run used in code_execution.ruby_llm' do
      payloads = []
      instrumenter = Object.new
      instrumenter.define_singleton_method(:instrument) do |name, payload, &block|
        result = block.call(payload)
        payloads << payload.dup if name == 'code_execution.ruby_llm'
        result
      end
      chat = RubyLLM.context do |config|
        config.sandbox = default_sandbox
        config.instrumenter = instrumenter
      end.chat(model: model_for(:openai), provider: :openai).with_code_execution(escalate_to: [online_sandbox])
      call = code_call('call_1', sandbox: 'online')
      chat.add_message(role: :assistant, content: '', tool_calls: { call.id => call })
      chat.approve('call_1')

      chat.tools[:run_code].call(language: 'ruby', code: 'puts 1', sandbox: 'online', tool_call: call)

      expect(payloads.sole).to include(sandbox: 'online', network: true, tool_call_id: 'call_1')
    end
  end
end
