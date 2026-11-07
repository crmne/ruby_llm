# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:events) { [] }
  let(:requests) { [] }
  let(:responses) { [] }
  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(echo_tool) }

  before do
    allow(chat.provider).to receive(:complete) do |messages, **|
      requests << messages.map { |message| [message.role, message.content.to_s] }
      responses.shift || answer('Done')
    end
    allow(RubyLLM).to receive(:instrument).and_call_original
  end

  def echo_tool(approval: false)
    calls = events
    Class.new(RubyLLM::Tool) do
      description 'Echoes the given text'
      parameter :text, description: 'Text to echo'
      requires_approval if approval
      define_method(:name) { 'echo' }
      define_method(:execute) do |text:|
        calls << [:executed, text]
        text
      end
    end
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def malformed_call(id = 'call_1', text: '{"text":"hel')
    RubyLLM::Message.new(
      role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
      tool_calls: { id => RubyLLM::ToolCall.new(id:, name: 'echo', malformed_arguments: text) }
    )
  end

  def tool_results
    chat.messages.select(&:tool_result?).map(&:content)
  end

  it 'answers the call with the parse error without running the tool, then asks the model again' do
    chat.before_tool_call { |call| events << [:before_tool_call, call.name] }
    chat.after_message { |message| events << [:after_message, message.role] }
    responses << malformed_call

    response = chat.ask('Echo hello')

    expect(response.content).to eq('Done')
    expect(tool_results.size).to eq(1)
    expect(tool_results.first).to start_with(
      '{"error":"The arguments for echo were not valid JSON ('
    )
    expect(tool_results.first).to end_with('Call echo again with a JSON object."}')
    expect(events).to eq([%i[after_message assistant], %i[after_message tool], %i[after_message assistant]])
    expect(requests.last.map(&:first)).to eq(%i[user assistant tool])
    expect(RubyLLM).not_to have_received(:instrument).with('tool_call.ruby_llm', any_args)
  end

  it 'says when the arguments were JSON but not an object' do
    responses << malformed_call(text: '["hello"]')

    chat.ask('Echo hello')

    expect(tool_results).to eq(
      ['{"error":"The arguments for echo were not a JSON object. Call echo again with a JSON object."}']
    )
  end

  it 'never asks for approval of a call that will not run' do
    chat.with_tools(nil).with_tools(echo_tool(approval: true))
    responses << malformed_call

    chat.ask('Echo hello')

    expect(chat).to be_complete
    expect(chat.pending_questions.select(&:approval?)).to be_empty
    expect(tool_results.first).to include('were not valid JSON')
    expect(events).to be_empty
  end

  it 'runs the well-formed calls of the same response' do
    good = RubyLLM::ToolCall.new(id: 'call_2', name: 'echo', arguments: { 'text' => 'hi' })
    response = malformed_call
    response.tool_calls['call_2'] = good
    responses << response

    chat.ask('Echo twice')

    expect(events).to eq([[:executed, 'hi']])
    expect(chat.messages.select(&:tool_result?).map(&:provider_call_id)).to contain_exactly('call_1', 'call_2')
  end

  it 'refuses a remote call whose arguments are malformed without asking' do
    remote = RubyLLM::ToolCall.new(id: 'approval_1', name: 'search', malformed_arguments: '{"q":', remote: true)
    refusal = RubyLLM::Message.new(role: :tool, content: nil, tool_call_id: 'approval_1')
    allow(chat.provider).to receive(:tool_approval_response).and_return(refusal)
    responses << RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'approval_1' => remote })

    chat.ask('Search')

    expect(chat.provider).to have_received(:tool_approval_response)
      .with(having_attributes(provider_call_id: 'approval_1'), approved: false, model: anything, protocol: anything)
    expect(chat).to be_complete
  end
end
