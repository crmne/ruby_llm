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

  describe 'tool results' do
    let(:laptop_transport) do
      Class.new do
        def request(message, **)
          result = case message[:method]
                   when 'server/discover' then { 'supportedVersions' => ['2026-07-28'] }
                   when 'tools/list' then { 'tools' => [{ 'name' => 'read_notes', 'inputSchema' => {} }] }
                   else { 'isError' => true, 'content' => [{ 'type' => 'text', 'text' => 'The laptop is offline' }] }
                   end
          { 'jsonrpc' => '2.0', 'id' => message[:id], 'result' => result }
        end

        def notify(*, **) = nil
        def cancel(*, **) = nil
        def close = nil
      end
    end

    it 'stores and reports a failed call as 2.0 did, through a custom transport' do
      results = []
      laptop = RubyLLM.mcp(transport: laptop_transport.new, name: 'laptop')
      allow(chat.provider).to receive(:complete).and_return(tool_call('read_notes', {}), answer)

      chat.with_mcp(laptop).after_tool_result { |result| results << result }.ask('Read my notes')

      expect(chat.messages.find(&:tool_result?).content).to eq('{"error":"The laptop is offline"}')
      expect(results).to eq([{ error: 'The laptop is offline' }])
    end

    it 'stores a successful result as before' do
      allow(chat.provider).to receive(:complete).and_return(tool_call('picture', {}), answer)

      chat.with_mcp(files).ask('Show me')

      message = chat.messages.find(&:tool_result?)
      expect(message.content).to eq("Here it is\n\npixel.png: file:///pixel.png")
      expect(message.attachments.first).to have_attributes(mime_type: 'image/png')
    end
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

  it 'passes server progress to after_tool_progress' do
    server_reports = []
    files_class.after_progress { |progress| server_reports << progress.value }
    allow(chat.provider).to receive(:complete).and_return(tool_call('slow', {}), answer)
    reports = []

    chat.with_mcp(files).after_tool_progress { |call, progress| reports << [call.name, progress.fraction] }
    chat.ask('Take your time')

    expect(reports).to eq([['slow', 0.5], ['slow', 1.0]])
    expect(server_reports).to eq([1, 2])
    expect(chat.messages.find(&:tool_result?).content).to eq('Finished')
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
      expect(chat).to be_waiting
      request = chat.pending_inputs.first
      expect(request).to have_attributes(message: 'Which environment?', tool_call: have_attributes(name: 'deploy'))

      chat.answer(request, environment: 'production').complete

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deployed to production')
      expect(chat).not_to be_awaiting_input
    end

    it 'answers with the defaults the server gave' do
      chat.with_mcp(files).ask('Deploy')
      chat.answer(chat.pending_inputs.first).complete

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deployed to staging')
    end

    it 'resumes a declined request' do
      chat.with_mcp(files).ask('Deploy')
      chat.decline(chat.pending_inputs.first).complete

      expect(chat.messages.find { |message| message.role == :tool }.content).to eq('Deploy cancelled')
    end

    it 'does not pause for input requests the MCP does not accept' do
      files_class.input_requests false

      chat.with_mcp(files).ask('Deploy')

      expect(chat).not_to be_awaiting_input
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

  describe 'MCP Apps' do
    before { files_class.extension :apps }

    it 'never offers the model tools that only a UI may call' do
      chat.with_mcp(files)

      expect(chat.tools.keys).to include(:forecast)
      expect(chat.tools.keys).not_to include(:refresh_forecast)
      expect(files.tools.map(&:name)).to include('refresh_forecast')
    end

    it 'keeps those tools from the model when given to the chat directly' do
      chat.with_tools(files.tools.find { |tool| tool.name == 'refresh_forecast' })

      expect(chat.tools).to be_empty
    end

    it 'keeps the result of a tool with a UI on its tool result message' do
      allow(chat.provider).to receive(:complete).and_return(tool_call('forecast', { 'city' => 'Rome' }), answer)

      chat.with_mcp(files).ask('How is the weather in Rome?')

      message = chat.messages.find(&:tool_result?)
      expect(message.content).to eq('Sunny in Rome')
      expect(message.mcp_result).to have_attributes(
        ui_uri: 'ui://spec/forecast', structured: { 'city' => 'Rome', 'temperature' => 24 },
        meta: { 'com.example/station' => 'spec' }
      )
    end

    it 'keeps no result for tools without a UI' do
      allow(chat.provider).to receive(:complete).and_return(tool_call('add', { 'a' => 2, 'b' => 3 }), answer)

      chat.with_mcp(files).ask('What is 2 + 3?')

      expect(chat.messages.find(&:tool_result?).mcp_result).to be_nil
    end

    it 'hands the server result to after_tool_result' do
      results = []
      allow(chat.provider).to receive(:complete).and_return(tool_call('forecast', { 'city' => 'Rome' }), answer)

      chat.with_mcp(files).after_tool_result { |result| results << result }.ask('How is the weather in Rome?')

      expect(results.first).to have_attributes(structured: { 'city' => 'Rome', 'temperature' => 24 })
    end
  end

  describe 'tasks' do
    before { files_class.extension :tasks }

    def server_tasks = files.send(:client).request('spec/tasks')

    def run_task(name)
      allow(chat.provider).to receive(:complete).and_return(tool_call(name, {}), answer)
      chat.with_mcp(files).ask('Run it')
    end

    it 'pauses a tool call that becomes a task, without waiting for it' do
      run_task('report')

      expect(chat).to be_awaiting_tasks
      expect(chat).to be_waiting
      expect(chat).not_to be_complete
      expect(chat.pending_tasks.first).to have_attributes(id: 'task-1', status: :working, poll_interval: 0.01,
                                                          tool_call: have_attributes(name: 'report'))
      expect(server_tasks['polls']).to eq('task-1' => 0)
    end

    it 'checks on each task once every time it completes, and resumes once they finish' do
      run_task('report')

      chat.complete
      expect(chat).to be_awaiting_tasks
      expect(chat.pending_tasks.first).to have_attributes(status: :working, status_message: 'Rendering')

      chat.complete
      expect(chat).to be_complete
      expect(chat).not_to be_awaiting_tasks
      expect(chat.messages.find(&:tool_result?).content).to eq('Report ready')
      expect(server_tasks['polls']).to eq('task-1' => 2)
    end

    it 'checks on a task without resuming the chat' do
      run_task('report')

      task = chat.pending_tasks.first.refresh.refresh

      expect(task).to be_completed
      expect(chat).to be_awaiting_tasks
      expect(chat.complete.content).to eq('Done')
    end

    it 'reports what a task is doing to after_tool_progress' do
      reports = []
      run_task('report')

      chat.after_tool_progress { |call, progress| reports << [call.name, progress.message] }.complete

      expect(reports).to eq([%w[report Rendering]])
    end

    it 'pauses on the input requests of a task until the user answers' do
      run_task('approve_report')
      chat.complete

      expect(chat).to be_awaiting_input
      expect(chat).not_to be_awaiting_tasks
      request = chat.pending_inputs.first
      expect(request).to have_attributes(message: 'Publish the report?',
                                         tool_call: have_attributes(name: 'approve_report'))

      chat.answer(request, approved: true).complete

      expect(chat).to be_complete
      expect(chat.messages.find(&:tool_result?).content).to eq('Approved: true')
    end

    it 'cancels its tasks when the chat is cancelled' do
      run_task('endless_report')
      task = chat.pending_tasks.first

      chat.cancel
      expect { chat.complete }.to raise_error(RubyLLM::CancelledError)

      expect(server_tasks['cancelled']).to eq([task.id])
      expect(chat).not_to be_awaiting_tasks
      expect(chat).not_to be_waiting
    end

    it 'raises the error a task failed with' do
      run_task('broken_report')

      expect { chat.complete }.to raise_error(RubyLLM::MCP::Error, 'Renderer crashed')
    end

    it 'refuses a new question while a task runs' do
      run_task('report')

      expect { chat.ask('Anything else?') }.to raise_error(RubyLLM::PendingToolCallsError, /waiting for tasks/)
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

  it 'refuses a deferred tool and an MCP tool with the same name' do
    echo = Class.new(RubyLLM::Tool) do
      def self.tool_name = 'echo'
      def execute(text:) = text
    end

    chat.with_tools(echo, defer: true).with_mcp(files)

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
