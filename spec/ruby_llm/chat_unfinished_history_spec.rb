# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:requests) { [] }

  let(:lookup_tool) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do
        runs << :lookup
        'found'
      end
    end
  end

  let(:approval_tool) do
    Class.new(RubyLLM::Tool) do
      requires_approval

      define_method(:name) { 'dangerous' }
      define_method(:execute) { 'done' }
    end
  end

  def unfinished
    '{"error":"The tool call did not finish."}'
  end

  def tool_call(id, name = 'lookup')
    RubyLLM::ToolCall.new(id: id, name: name, arguments: {})
  end

  def round(*calls)
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls.to_h { |call| [call.id, call] })
  end

  def tool_result(id)
    RubyLLM::Message.new(role: :tool, content: 'found', tool_call_id: id)
  end

  def placeholder
    RubyLLM::Message.new(role: :assistant, content: '')
  end

  def chat_with(*history)
    chat = RubyLLM.chat(model: model_for(:openai)).with_tools(lookup_tool, approval_tool)
    history.each { |message| chat.add_message(message) }
    allow(chat.provider).to receive(:complete) do |messages, **|
      requests << messages
      RubyLLM::Message.new(role: :assistant, content: 'Answered', input_tokens: 1, output_tokens: 1)
    end
    chat
  end

  def sent(request = requests.last)
    request.map { |message| [message.role, message.content, message.tool_call_id].compact }
  end

  it 'leaves blank assistant messages out of a request' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Hi'), placeholder)

    chat.ask('Still there?')

    expect(sent).to eq([[:user, 'Hi'], [:user, 'Still there?']])
    expect(chat.messages.map(&:role)).to eq(%i[user assistant user assistant])
  end

  it 'answers a call the conversation moved past as unfinished' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Look twice'), round(tool_call('a'), tool_call('b')),
                     tool_result('a'), placeholder, RubyLLM::Message.new(role: :user, content: 'Hello?'))

    chat.complete

    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', 'a'], [:tool, unfinished, 'b'],
                        [:user, 'Hello?']])
    expect(chat.messages.count(&:tool_result?)).to eq(1)
    expect(executions).to be_empty
  end

  it 'runs the calls a crash left unfinished in the last round when the chat resumes' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Look twice'), round(tool_call('a'), tool_call('b')),
                     tool_result('a'), placeholder)

    expect(chat).not_to be_complete
    expect { chat.ask_later('Hello?') }.to raise_error(RubyLLM::PendingToolCallsError, /lookup/)

    expect(chat.complete.content).to eq('Answered')
    expect(executions).to eq([:lookup])
    expect(sent).to eq([[:user, 'Look twice'], [:assistant, ''], [:tool, 'found', 'a'], [:tool, 'found', 'b']])
  end

  it 'leaves a call that waits on approval unanswered' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Do it'), round(tool_call('a', 'dangerous')))

    expect(chat.complete).to eq(chat.messages.last)
    expect(chat).to be_awaiting_approval

    chat.generate

    expect(sent).to eq([[:user, 'Do it'], [:assistant, '']])
  end

  it 'leaves a call that waits on input or a task unanswered' do
    states = { 'a' => { 'requests' => [{ 'key' => 'environment', 'response' => nil }] },
               'b' => { 'task' => { 'taskId' => 'task-1' } } }
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Deploy'), round(tool_call('a'), tool_call('b')))
    chat.input_checker = ->(call) { states[call.id] }

    expect(chat).to be_waiting

    chat.generate

    expect(sent).to eq([[:user, 'Deploy'], [:assistant, '']])
  end

  it 'answers a call that waited on approval as unfinished once the conversation moved past it' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Do it'), round(tool_call('a', 'dangerous')),
                     placeholder, RubyLLM::Message.new(role: :user, content: 'Never mind'))

    chat.complete

    expect(sent).to eq([[:user, 'Do it'], [:assistant, ''], [:tool, unfinished, 'a'], [:user, 'Never mind']])
  end

  it 'leaves the calls of the latest round for the loop to run' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Look'), round(tool_call('a')))

    chat.generate

    expect(sent).to eq([[:user, 'Look'], [:assistant, '']])
    expect(executions).to be_empty
  end

  describe 'a provider-executed call the conversation moved past' do
    let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai, protocol: :responses) }

    def request_item
      { 'type' => 'mcp_approval_request', 'id' => 'mcpr_1', 'name' => 'search', 'arguments' => '{}',
        'server_label' => 'docs' }
    end

    before do
      remote = RubyLLM::ToolCall.new(id: 'mcpr_1', name: 'search', arguments: {}, remote: true)
      chat.add_message(role: :user, content: 'Search the docs')
      chat.add_message(role: :assistant, content: '', tool_calls: { remote.id => remote }, raw_content: [request_item])
      chat.add_message(role: :user, content: 'Never mind')
    end

    it 'is refused the way the provider expects' do
      expect(chat.render[:input]).to eq(
        [{ role: 'user', content: 'Search the docs' },
         request_item,
         { type: 'mcp_approval_response', approval_request_id: 'mcpr_1', approve: false },
         { role: 'user', content: 'Never mind' }]
      )
    end

    it 'is answered as unfinished after a move to another provider' do
      messages = chat.with_model(model_for(:anthropic), provider: :anthropic).render[:messages]

      expect(messages[2]).to eq(
        role: 'user',
        content: [{ type: 'tool_result', tool_use_id: 'mcpr_1', content: [{ type: 'text', text: unfinished }] }]
      )
    end
  end

  it 'keeps an empty answer from the model as the end of the conversation' do
    chat = chat_with(RubyLLM::Message.new(role: :user, content: 'Hi'),
                     RubyLLM::Message.new(role: :assistant, content: '', finish_reason: :stop, output_tokens: 0))

    expect(chat).to be_complete

    chat.complete

    expect(requests).to be_empty
  end
end
