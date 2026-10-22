# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:anthropic) }
  let(:chat) { RubyLLM.chat(model:, provider: :anthropic) }
  let(:requests) { [] }
  let(:executed) { [] }

  around { |example| Timeout.timeout(10) { example.run } }

  def local_tool(name, namespace: nil, approval: false, &action)
    klass = Class.new(RubyLLM::Tool)
    klass.define_singleton_method(:tool_name) { name }
    klass.namespace(namespace) if namespace
    klass.requires_approval if approval
    klass.define_method(:execute) { action ? action.call : 'OK' }
    klass.new
  end

  def call(id, name, namespace: nil)
    { type: 'tool_use', id:, name:, input: {} }.tap { |block| block[:toolset_name] = namespace if namespace }
  end

  def stub_turns(*contents)
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return do |request|
      requests << JSON.parse(request.body)
      blocks = contents.shift or raise 'Unexpected request'
      reason = blocks.any? { |block| block[:type] == 'tool_use' } ? 'tool_use' : 'end_turn'
      { body: JSON.generate(id: 'msg_fixture', type: 'message', role: 'assistant', model:,
                            content: blocks, stop_reason: reason,
                            usage: { input_tokens: 10, output_tokens: 2 }),
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  def enable_computer
    chat.with_provider_tools({ type: 'computer_toolset_20260801' })
  end

  def finish
    [{ type: 'text', text: 'Done' }]
  end

  it 'preserves a native member identity in typed calls and serialized transcripts' do
    stub_turns([call('native', 'screenshot', namespace: 'computer')])

    reply = enable_computer.ask_later('Inspect').generate
    tool_call = reply.tool_calls.values.first
    restored = RubyLLM::Message.new(JSON.parse(JSON.generate(reply.to_h)).transform_keys(&:to_sym))

    expect(tool_call.namespace).to eq('computer')
    expect(tool_call).to be_sequential
    expect(restored.tool_calls.values.first.to_h).to eq(tool_call.to_h)
    expect(reply.raw_content).to be_nil
  end

  it 'routes native and ordinary calls with the same member name to different executors' do
    native = local_tool('screenshot', namespace: 'computer') do
      executed << :native
      'Native'
    end
    ordinary = local_tool('screenshot') do
      executed << :ordinary
      'Ordinary'
    end
    stub_turns([call('native', 'screenshot', namespace: 'computer'), call('ordinary', 'screenshot')], finish)

    enable_computer.with_tools(native, ordinary).ask('Inspect')

    expect(executed).to eq(%i[native ordinary])
    expect(chat.tools.keys).to contain_exactly(:'computer.screenshot', :screenshot)
    definitions = requests.first['tools']
    expect(definitions.count { |tool| tool['name'] == 'screenshot' }).to eq(1)
    expect(definitions).to include('type' => 'computer_toolset_20260801')
    assistant = requests.last['messages'][1]['content']
    results = requests.last['messages'][2]['content']
    expect(assistant.first).to include('name' => 'screenshot', 'toolset_name' => 'computer')
    expect(assistant.last).not_to have_key('toolset_name')
    expect(results.first).to include('toolset_name' => 'computer')
    expect(results.last).not_to have_key('toolset_name')
  end

  it 'returns screenshot attachments with the native result identity' do
    image = RubyLLM::Attachment.new(StringIO.new('synthetic image'), filename: 'screen.png')
    native = local_tool('screenshot', namespace: 'computer') { image }
    stub_turns([call('native', 'screenshot', namespace: 'computer')], finish)

    enable_computer.with_tools(native).ask('Inspect')

    result = requests.last['messages'][2]['content'].first
    expect(result).to include('type' => 'tool_result', 'toolset_name' => 'computer', 'tool_use_id' => 'native')
    expect(result['content'].last).to include('type' => 'image')
    expect(result).not_to have_key('is_error')
  end

  it 'does not route a namespaced call to an ordinary same-name tool when its executor is absent' do
    ordinary = local_tool('screenshot') do
      executed << :ordinary
      'Wrong executor'
    end
    stub_turns([call('native', 'screenshot', namespace: 'computer')], finish)

    enable_computer.with_tools(ordinary).ask('Inspect')

    expect(executed).to be_empty
    expect(requests.last['messages'][2]['content'].first).to include('is_error' => true, 'toolset_name' => 'computer')
  end

  it 'runs ordered native calls sequentially even when ordinary tools use threads' do
    first = local_tool('left_click', namespace: 'computer') do
      executed << :start
      sleep 0.02
      executed << :finish
      'OK'
    end
    second = local_tool('screenshot', namespace: 'computer') do
      executed << :screenshot
      'OK'
    end
    stub_turns(
      [call('first', 'left_click', namespace: 'computer'), call('second', 'screenshot', namespace: 'computer')], finish
    )

    enable_computer.with_tools(first, second).with_tool_options(concurrency: :threads).ask('Inspect')

    expect(executed).to eq(%i[start finish screenshot])
  end

  it 'answers every later action as not executed after a recoverable failure' do
    first = local_tool('left_click', namespace: 'computer') do
      executed << :click
      { error: 'Click failed' }
    end
    second = local_tool('screenshot', namespace: 'computer') do
      executed << :screenshot
      'OK'
    end
    stub_turns(
      [call('first', 'left_click', namespace: 'computer'), call('second', 'screenshot', namespace: 'computer')], finish
    )

    enable_computer.with_tools(first, second).with_tool_options(concurrency: :threads).ask('Inspect')

    expect(executed).to eq([:click])
    results = requests.last['messages'][2]['content']
    expect(results.map { |result| result['is_error'] }).to eq([true, true])
    halt_text = 'Not executed: an earlier computer action in this turn failed.'
    expect(results.last['content']).to eq([{ 'type' => 'text', 'text' => halt_text }])
  end

  it 'does not execute a later action while an earlier approval is pending' do
    first = local_tool('left_click', namespace: 'computer', approval: true) do
      executed << :click
      'OK'
    end
    second = local_tool('screenshot', namespace: 'computer') do
      executed << :screenshot
      'OK'
    end
    stub_turns(
      [call('first', 'left_click', namespace: 'computer'), call('second', 'screenshot', namespace: 'computer')], finish
    )
    enable_computer.with_tools(first, second).ask('Inspect')

    expect(executed).to be_empty
    chat.approve(chat.pending_approvals.first)
    chat.complete

    expect(executed).to eq(%i[click screenshot])
  end

  it 'holds later members behind a member paused on input while other calls proceed' do
    paused = local_tool('left_click', namespace: 'computer')
    log = executed
    paused.define_singleton_method(:execute) do
      answer = ask('Unlock the display?', unlock: { type: 'boolean', required: true })
      log << :click if answer.accepted?
      'OK'
    end
    later = local_tool('screenshot', namespace: 'computer') { executed << :screenshot }
    lookup = local_tool('lookup') { executed << :lookup }
    publish = local_tool('publish', approval: true) { executed << :publish }
    stub_turns([call('first', 'left_click', namespace: 'computer'), call('second', 'screenshot', namespace: 'computer'),
                call('third', 'lookup'), call('fourth', 'publish')], finish)

    enable_computer.with_tools(paused, later, lookup, publish).ask('Inspect')
    expect(executed).to eq(%i[lookup])

    chat.approve(chat.pending_approvals.first).complete
    expect(executed).to eq(%i[lookup publish])
    expect(chat).to be_awaiting_input

    chat.answer(chat.pending_inputs.first, unlock: true).complete
    expect(executed).to eq(%i[lookup publish click screenshot])
    expect(requests.size).to eq(2)
  end

  it 'answers denied and skipped actions without requiring approval to skip the rest' do
    first = local_tool('left_click', namespace: 'computer', approval: true) do
      executed << :click
      'OK'
    end
    second = local_tool('screenshot', namespace: 'computer', approval: true) do
      executed << :screenshot
      'OK'
    end
    stub_turns(
      [call('first', 'left_click', namespace: 'computer'), call('second', 'screenshot', namespace: 'computer')], finish
    )
    enable_computer.with_tools(first, second).ask('Inspect')

    chat.deny(chat.pending_approvals.first)
    chat.complete

    expect(executed).to be_empty
    expect(chat).to be_complete
    expect(requests.last['messages'][2]['content'].map { |result| result['is_error'] }).to eq([true, true])
  end

  it 'preserves failure ordering through a serialized mid-round restart' do
    native = local_tool('screenshot', namespace: 'computer') do
      executed << :screenshot
      'OK'
    end
    stub_turns([call('first', 'left_click', namespace: 'computer'),
                call('second', 'screenshot', namespace: 'computer')])
    reply = enable_computer.with_tools(native).ask_later('Inspect').generate
    first = reply.tool_calls.values.first
    chat.add_message(role: :tool, content: JSON.generate(error: 'Click failed'), tool_call_id: first.id)
    restored = RubyLLM.chat(model:, provider: :anthropic).with_tools(native)
    restored.messages = JSON.parse(JSON.generate(chat.messages.map(&:to_h))).map do |message|
      message.transform_keys(&:to_sym)
    end

    restored.run_tools

    expect(executed).to be_empty
    expect(restored.messages.last.tool_error_message).to eq('Not executed: an earlier action in this turn failed.')
  end

  it 'does not reuse remembered approvals in another namespace' do
    native = local_tool('screenshot', namespace: 'computer', approval: true) do
      executed << :native
      'OK'
    end
    browser = local_tool('screenshot', namespace: 'browser', approval: true) do
      executed << :browser
      'OK'
    end
    stub_turns([call('first', 'screenshot', namespace: 'computer')], finish,
               [call('second', 'screenshot', namespace: 'browser')])
    enable_computer.with_tools(native, browser).ask('Inspect')
    chat.approve(chat.pending_approvals.first, remember: true).complete

    chat.ask('Inspect another environment')

    expect(executed).to eq([:native])
    expect(chat.pending_approvals.map(&:namespace)).to eq(['browser'])
  end

  it 'does not remember an approval for a qualified-looking ordinary tool registered later' do
    native = local_tool('screenshot', namespace: 'computer', approval: true)
    ordinary = local_tool('computer.screenshot', approval: true) { executed << :ordinary }
    stub_turns([call('first', 'screenshot', namespace: 'computer')], finish,
               [call('second', 'computer.screenshot')])
    enable_computer.with_tools(native).ask('Inspect')
    chat.approve(chat.pending_approvals.first, remember: true).complete
    chat.with_tools(nil).with_tools(ordinary)

    chat.ask('Use the other tool')

    expect(executed).to be_empty
    expect(chat.pending_approvals.map(&:name)).to eq(['computer.screenshot'])
  end

  it 'routes the same member name independently in two native groups' do
    computer = local_tool('screenshot', namespace: 'computer') { executed << :computer }
    browser = local_tool('screenshot', namespace: 'browser') { executed << :browser }
    stub_turns(
      [call('first', 'screenshot', namespace: 'computer'), call('second', 'screenshot', namespace: 'browser')], finish
    )

    chat.with_provider_tools({ type: 'computer_toolset_20260801' }, { type: 'browser_toolset_20260801' })
        .with_tools(computer, browser).ask('Inspect')

    expect(executed).to eq(%i[computer browser])
    expect(requests.last['messages'][2]['content'].map { |result| result['toolset_name'] }).to eq(%w[computer browser])
  end

  it 'inherits and resets a tool namespace through the existing class configuration pattern' do
    parent = local_tool('screenshot', namespace: 'computer').class
    child = Class.new(parent)

    expect(child.namespace).to eq('computer')
    child.namespace(nil)
    expect(child.new.namespace).to be_nil
    expect(parent.namespace).to eq('computer')
  end

  it 'rejects a namespace before a request when the selected protocol cannot express it' do
    native = local_tool('screenshot', namespace: 'computer')
    other = RubyLLM.chat(model: model_for(:gemini), provider: :gemini).with_tools(native)

    expect { other.render }.to raise_error(RubyLLM::Error, /namespace/i)
  end

  it 'rejects an Anthropic namespace that is not a native client toolset instead of dropping the tool' do
    grouped = local_tool('lookup', namespace: 'crm')

    expect { chat.with_tools(grouped).render }.to raise_error(RubyLLM::Error, /crm/)
  end

  it 'rejects forcing a native member on Anthropic, which cannot name one in a tool choice' do
    native = local_tool('screenshot', namespace: 'computer')
    enable_computer.with_tools(native).with_tool_options(choice: native.class)

    expect { chat.render }.to raise_error(RubyLLM::Error, /computer\.screenshot/)
  end

  it 'rejects forcing a namespaced function on Responses, which cannot name one in a tool choice' do
    grouped = local_tool('lookup', namespace: 'crm')
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
    other.with_tools(grouped).with_tool_options(choice: grouped.class)

    expect { other.render }.to raise_error(RubyLLM::Error, /crm\.lookup/)
  end

  it 'still forces an ordinary tool next to namespaced members' do
    plain = local_tool('screenshot')
    enable_computer.with_tools(plain, local_tool('screenshot', namespace: 'computer'))

    expect(chat.with_tool_options(choice: plain.class).render[:tool_choice]).to include(type: :tool, name: :screenshot)
  end

  it 'rejects namespaced history on an incompatible protocol after the tools are removed' do
    other = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
    member = RubyLLM::ToolCall.new(id: 'native', name: 'screenshot', namespace: 'computer')
    other.add_message(role: :assistant, content: nil, tool_calls: { member.id => member })

    expect { other.render }.to raise_error(RubyLLM::Error, /namespace/i)
  end

  it 'uses the browser halt text for a skipped member without invoking it' do
    native = local_tool('screenshot', namespace: 'browser') { executed << :browser }
    stub_turns([call('first', 'missing', namespace: 'browser'), call('second', 'screenshot', namespace: 'browser')],
               finish)

    chat.with_provider_tools({ type: 'browser_toolset_20260801' }).with_tools(native).ask('Inspect')

    expect(executed).to be_empty
    expect(requests.last['messages'][2]['content'].last).to include(
      'is_error' => true, 'toolset_name' => 'browser',
      'content' => [{ 'type' => 'text', 'text' => 'Not executed: an earlier action in this turn failed.' }]
    )
  end

  it 'preserves native identity and ordering metadata while assembling input fragments' do
    native = local_tool('screenshot', namespace: 'computer') { 'Synthetic screenshot result' }
    events = [
      { type: 'message_start', message: { model: model, usage: { input_tokens: 10 } } },
      { type: 'content_block_start', index: 0, content_block: call('native', 'screenshot', namespace: 'computer') },
      { type: 'content_block_delta', index: 0, delta: { type: 'input_json_delta', partial_json: '{}' } },
      { type: 'content_block_stop', index: 0 },
      { type: 'message_delta', delta: { stop_reason: 'tool_use' }, usage: { output_tokens: 2 } },
      { type: 'message_stop' }
    ]
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .to_return(body: events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join,
                 headers: { 'Content-Type' => 'text/event-stream' })

    reply = enable_computer.with_tools(native).ask_later('Inspect').generate { |_chunk| nil }
    chat.run_tools

    member = reply.tool_calls.values.first
    expect(member.namespace).to eq('computer')
    expect(member).to be_sequential
    expect(chat.render[:messages][2][:content].first[:toolset_name]).to eq('computer')
  end

  it 'uses the same namespace for Responses function groups and local routing' do
    native = local_tool('lookup', namespace: 'crm') do
      executed << :crm
      'CRM answer'
    end
    ordinary = local_tool('lookup') do
      executed << :ordinary
      'Wrong executor'
    end
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses).with_tools(native,
                                                                                                        ordinary)
    first = { id: 'resp_first', status: 'completed', model: model_for(:openai),
              output: [{ type: 'function_call', call_id: 'lookup_1', name: 'lookup',
                         namespace: 'crm', arguments: '{}' }],
              usage: { input_tokens: 10, output_tokens: 2 } }
    final = { id: 'resp_final', status: 'completed', model: model_for(:openai),
              output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Done' }] }],
              usage: { input_tokens: 20, output_tokens: 2 } }
    bodies = [first, final]
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return do |request|
      requests << JSON.parse(request.body)
      { body: JSON.generate(bodies.shift), headers: { 'Content-Type' => 'application/json' } }
    end

    other.ask('Find customer')

    expect(executed).to eq([:crm])
    namespace = requests.first['tools'].find { |definition| definition['type'] == 'namespace' }
    expect(namespace).to include('name' => 'crm')
    expect(namespace['tools'].map { |definition| definition['name'] }).to eq(['lookup'])
    expect(other.messages[1].tool_calls.values.first.namespace).to eq('crm')
    expect(other.messages[1].tool_calls.values.first).not_to be_sequential
  end

  it 'adds tool search when a Responses namespace contains a deferred member' do
    native = local_tool('lookup', namespace: 'crm')
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses).with_tools(native,
                                                                                                        defer: true)

    payload = other.render

    expect(payload[:tools]).to include(type: 'tool_search')
    expect(payload[:tools].first[:tools].first).to include(defer_loading: true)
  end

  it 'rejects an ambiguous qualified registration instead of replacing a different tool' do
    native = local_tool('screenshot', namespace: 'computer')
    ordinary = local_tool('computer.screenshot')

    expect { chat.with_tools(native, ordinary) }.to raise_error(ArgumentError, /Ambiguous tool name/)
  end

  it 'does not use a qualified-looking ordinary call to invoke a native executor' do
    native = local_tool('screenshot', namespace: 'computer') do
      executed << :native
      'Wrong executor'
    end
    stub_turns([call('ordinary', 'computer.screenshot')], finish)

    enable_computer.with_tools(native).ask('Inspect')

    expect(executed).to be_empty
  end

  it 'restores and resumes a namespaced task through its own executor' do
    task_class = Class.new(RubyLLM::Task)
    log = executed
    native = local_tool('screenshot', namespace: 'computer') do
      RubyLLM::Task.new(status: :input_required, data: { run_id: 7 })
    end
    native.define_singleton_method(:task) do |state, tool_call:|
      task_class.load(state, tool_call:)
    end
    native.define_singleton_method(:resume) do |task, **|
      log << task.data
      'Screenshot ready'
    end
    ordinary = local_tool('screenshot')
    ordinary.define_singleton_method(:task) { |*| raise 'Wrong task executor' }
    stub_turns([call('native', 'screenshot', namespace: 'computer')], finish)

    enable_computer.with_tools(native, ordinary).ask('Inspect')

    task = chat.pending_tasks.sole
    expect(task).to be_an_instance_of(task_class)
    expect(task.tool_call.namespace).to eq('computer')
    expect(chat.complete.content).to eq('Done')
    expect(executed).to eq([{ 'run_id' => 7 }])
    expect(chat.messages.find(&:tool_result?).content).to eq('Screenshot ready')
  end

  it 'restores a generic task after its namespaced executor is removed' do
    native = local_tool('screenshot', namespace: 'computer') do
      RubyLLM::Task.new(status: :input_required, data: { run_id: 7 })
    end
    stub_turns([call('native', 'screenshot', namespace: 'computer')])
    enable_computer.with_tools(native).ask('Inspect')
    chat.with_tools(nil)

    task = chat.pending_tasks.sole

    expect(task).to be_an_instance_of(RubyLLM::Task)
    expect(task).to have_attributes(status: :input_required, data: { 'run_id' => 7 })
    expect(task.tool_call.namespace).to eq('computer')
  end

  it 'preserves an MCP task after its namespaced executor is removed' do
    native = local_tool('screenshot', namespace: 'computer') do
      RubyLLM::MCP::Task.new(nil, { 'taskId' => 'remote-task', 'status' => 'input_required' })
    end
    native.define_singleton_method(:task) do |state, tool_call:|
      RubyLLM::MCP::Task.load(nil, state, tool_call:)
    end
    stub_turns([call('native', 'screenshot', namespace: 'computer')])
    enable_computer.with_tools(native).ask('Inspect')
    chat.with_tools(nil)

    task = chat.pending_tasks.sole

    expect(task).to be_an_instance_of(RubyLLM::MCP::Task)
    expect(task).to have_attributes(id: 'remote-task', status: :input_required)
    expect(task.tool_call.namespace).to eq('computer')
  end
end
