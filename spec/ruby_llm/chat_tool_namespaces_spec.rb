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
    expect(chat.tools.keys).to contain_exactly(:computer_screenshot, :screenshot)
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
    expect(restored.messages.last.tool_error_message)
      .to eq('Not executed: an earlier computer action in this turn failed.')
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
    ordinary = local_tool('computer_screenshot', approval: true) { executed << :ordinary }
    stub_turns([call('first', 'screenshot', namespace: 'computer')], finish,
               [call('second', 'computer_screenshot')])
    enable_computer.with_tools(native).ask('Inspect')
    chat.approve(chat.pending_approvals.first, remember: true).complete
    chat.with_tools(nil).with_tools(ordinary)

    chat.ask('Use the other tool')

    expect(executed).to be_empty
    expect(chat.pending_approvals.map(&:name)).to eq(['computer_screenshot'])
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

  it 'joins a namespace into the function name on a protocol without namespaces' do
    grouped = local_tool('lookup', namespace: 'crm')
    other = RubyLLM.chat(model: model_for(:gemini), provider: :gemini).with_tools(grouped)

    declarations = other.render[:tools].flat_map { |tool| tool[:functionDeclarations] }

    expect(declarations.map { |declaration| declaration[:name] }).to eq(['crm_lookup'])
  end

  it 'calls a namespaced Anthropic function by its joined name and keeps its namespace' do
    grouped = local_tool('lookup', namespace: 'crm') do
      executed << :crm
      'CRM answer'
    end
    stub_turns([call('crm', 'crm_lookup')], finish)

    chat.with_tools(grouped).ask('Find customer')

    expect(executed).to eq([:crm])
    expect(requests.first['tools'].map { |tool| tool['name'] }).to eq(['crm_lookup'])
    expect(chat.messages[1].tool_calls.values.first).to have_attributes(name: 'lookup', namespace: 'crm')
    replayed = requests.last['messages'][1]['content'].first
    expect(replayed).to include('name' => 'crm_lookup')
    expect(replayed).not_to have_key('toolset_name')
    expect(requests.last['messages'][2]['content'].first).not_to have_key('toolset_name')
  end

  it 'forces a namespaced function by its joined name where the namespace is joined' do
    grouped = local_tool('lookup', namespace: 'crm')

    payload = chat.with_tools(grouped).with_tool_options(choice: grouped.class).render

    expect(payload[:tool_choice]).to include(type: :tool, name: :crm_lookup)
  end

  it 'rejects forcing a native member on Anthropic, which cannot name one in a tool choice' do
    native = local_tool('screenshot', namespace: 'computer')
    enable_computer.with_tools(native).with_tool_options(choice: native.class)

    expect { chat.render }.to raise_error(RubyLLM::Error, /computer_screenshot/)
  end

  it 'rejects forcing a namespaced function on Responses, which cannot name one in a tool choice' do
    grouped = local_tool('lookup', namespace: 'crm')
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
    other.with_tools(grouped).with_tool_options(choice: grouped.class)

    expect { other.render }.to raise_error(RubyLLM::Error, /crm_lookup/)
  end

  it 'keeps a joined-name function deferred for tool search' do
    chat.with_tools(local_tool('lookup', namespace: 'crm'), defer: true)

    expect(chat.render[:tools].first).to include(name: 'crm_lookup', defer_loading: true)
  end

  it 'joins only the namespaces Anthropic has no native form for in a replayed turn' do
    member = RubyLLM::ToolCall.new(id: 'native', name: 'screenshot', namespace: 'computer')
    grouped = RubyLLM::ToolCall.new(id: 'crm', name: 'lookup', namespace: 'crm')
    chat.add_message(role: :user, content: 'Inspect')
    chat.add_message(role: :assistant, content: nil, tool_calls: { member.id => member, grouped.id => grouped })

    blocks = chat.render[:messages].last[:content]

    expect(blocks.map { |block| block.slice(:name, :toolset_name) })
      .to eq([{ name: 'screenshot', toolset_name: 'computer' }, { name: 'crm_lookup' }])
  end

  it 'counts tokens with namespaced tools under their joined names' do
    bodies = []
    stub_request(:post, 'https://api.anthropic.com/v1/messages/count_tokens').to_return do |request|
      bodies << JSON.parse(request.body)
      { body: JSON.generate(input_tokens: 12), headers: { 'Content-Type' => 'application/json' } }
    end
    protocol = RubyLLM::Protocols::Anthropic.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config), chat.model)
    tools = { crm_lookup: local_tool('lookup', namespace: 'crm') }

    protocol.count_tokens([RubyLLM::Message.new(role: :user, content: 'Hi')], tools:)

    expect(bodies.first['tools'].map { |tool| tool['name'] }).to eq(['crm_lookup'])
  end

  it 'refuses a namespaced tool whose joined name another tool already has' do
    expect { chat.with_tools(local_tool('crm_lookup'), local_tool('lookup', namespace: 'crm')) }
      .to raise_error(ArgumentError, /Two tools are named crm_lookup/)
  end

  it 'still forces an ordinary tool next to namespaced members' do
    plain = local_tool('screenshot')
    enable_computer.with_tools(plain, local_tool('screenshot', namespace: 'computer'))

    expect(chat.with_tool_options(choice: plain.class).render[:tool_choice]).to include(type: :tool, name: :screenshot)
  end

  it 'replays namespaced history by joined names on a protocol without namespaces' do
    other = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
    member = RubyLLM::ToolCall.new(id: 'native', name: 'screenshot', namespace: 'computer')
    other.add_message(role: :user, content: 'Inspect')
    other.add_message(role: :assistant, content: nil, tool_calls: { member.id => member })
    other.add_message(role: :tool, content: 'OK', tool_call_id: member.id)

    parts = other.render[:contents].flat_map { |content| content[:parts] }

    expect(parts.filter_map { |part| part.dig(:functionCall, :name) }).to eq(['computer_screenshot'])
    expect(parts.filter_map { |part| part.dig(:functionResponse, :name) }).to eq(['computer_screenshot'])
    expect(member.name).to eq('screenshot')
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

  it 'preserves native identity while assembling input fragments' do
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
  end

  def stub_responses(*outputs)
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return do |request|
      requests << JSON.parse(request.body)
      output = outputs.shift or raise 'Unexpected request'
      { body: JSON.generate(id: 'resp_fixture', status: 'completed', model: model_for(:openai), output:,
                            usage: { input_tokens: 10, output_tokens: 2 }),
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  def responses_answer
    [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'Done' }] }]
  end

  it 'runs a deferred function that Responses tool search calls under a namespace of its own name' do
    weather = local_tool('weather_lookup') do
      executed << :weather
      'Sunny'
    end
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
                   .with_tools(weather, local_tool('stock_price'), defer: true)
    search = [{ type: 'tool_search_call', id: 'tsc_1', call_id: nil, execution: 'server', status: 'completed',
                arguments: { paths: ['weather_lookup'] } },
              { type: 'tool_search_output', id: 'tso_1', call_id: nil, execution: 'server', status: 'completed',
                tools: [{ type: 'function', name: 'weather_lookup', parameters: { type: 'object', properties: {} } }] }]
    stub_responses([*search, { type: 'function_call', id: 'fc_1', call_id: 'weather_1', name: 'weather_lookup',
                               namespace: 'weather_lookup', arguments: '{}' }], responses_answer)

    other.ask('What is the weather?')

    expect(executed).to eq([:weather])
    call = other.messages[1].tool_calls.values.first
    expect([call.name, call.namespace]).to eq(['weather_lookup', nil])
    replayed = requests.last['input'].find { |item| item['type'] == 'function_call' }
    expect(replayed).to include('name' => 'weather_lookup', 'namespace' => 'weather_lookup')
  end

  it 'keeps a Responses namespace that differs from the name of a function outside any namespace' do
    ordinary = local_tool('lookup') do
      executed << :ordinary
      'Wrong executor'
    end
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses).with_tools(ordinary)
    stub_responses([{ type: 'function_call', call_id: 'lookup_1', name: 'lookup', namespace: 'crm',
                      arguments: '{}' }], responses_answer)

    other.ask('Find customer')

    expect(executed).to be_empty
    expect(other.messages[1].tool_calls.values.first.namespace).to eq('crm')
  end

  it 'keeps a Responses namespace the request declared, though named like its member' do
    namespaced = local_tool('lookup', namespace: 'lookup') do
      executed << :namespaced
      'Namespaced'
    end
    ordinary = local_tool('lookup') do
      executed << :ordinary
      'Wrong executor'
    end
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)
                   .with_tools(namespaced, ordinary)
    stub_responses([{ type: 'function_call', call_id: 'lookup_1', name: 'lookup', namespace: 'lookup',
                      arguments: '{}' }], responses_answer)

    other.ask('Find customer')

    expect(executed).to eq([:namespaced])
    expect(other.messages[1].tool_calls.values.first.namespace).to eq('lookup')
  end

  it 'runs every Responses namespace call after an earlier one fails' do
    failing = local_tool('lookup', namespace: 'crm') { { error: 'Not found' } }
    later = local_tool('orders', namespace: 'crm') do
      executed << :orders
      'Orders'
    end
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses).with_tools(failing, later)
    output = [{ type: 'function_call', call_id: 'lookup_1', name: 'lookup', namespace: 'crm', arguments: '{}' },
              { type: 'function_call', call_id: 'orders_1', name: 'orders', namespace: 'crm', arguments: '{}' }]
    other.add_message(role: :user, content: 'Find customer')
    other.add_message(RubyLLM::Message.new(
                        role: :assistant, content: nil,
                        tool_calls: output.to_h do |item|
                          call = RubyLLM::ToolCall.new(provider_call_id: item[:call_id], name: item[:name],
                                                       namespace: item[:namespace])
                          [call.id, call]
                        end
                      ))

    other.run_tools

    expect(executed).to eq([:orders])
  end

  it 'describes a Responses namespace with the description its tools declare' do
    described = local_tool('lookup', namespace: 'crm')
    described.class.namespace('crm', description: 'Customer records')
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)

    group = other.with_tools(local_tool('orders', namespace: 'crm'), described).render[:tools].sole

    expect(group).to include(type: 'namespace', name: 'crm', description: 'Customer records')
    expect(group[:tools].map { |tool| tool[:name] }).to eq(%w[orders lookup])
  end

  it 'leaves the description out of a Responses namespace none of its tools describe' do
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses)

    expect(other.with_tools(local_tool('lookup', namespace: 'crm')).render[:tools].sole).not_to have_key(:description)
  end

  it 'adds tool search when a Responses namespace contains a deferred member' do
    native = local_tool('lookup', namespace: 'crm')
    other = RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses).with_tools(native,
                                                                                                        defer: true)

    payload = other.render

    expect(payload[:tools]).to include(type: 'tool_search')
    expect(payload[:tools].first[:tools].first).to include(defer_loading: true)
  end

  it 'does not use a qualified-looking ordinary call to invoke a native executor' do
    native = local_tool('screenshot', namespace: 'computer') do
      executed << :native
      'Wrong executor'
    end
    stub_turns([call('ordinary', 'computer_screenshot')], finish)

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
