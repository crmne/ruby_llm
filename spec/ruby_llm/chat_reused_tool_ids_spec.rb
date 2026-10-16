# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:lookup) do
    calls = executions
    Class.new(RubyLLM::Tool) do
      define_method(:name) { 'lookup' }
      define_method(:execute) do |city:|
        calls << city
        "Weather in #{city}"
      end
    end
  end
  let(:chat) { RubyLLM.chat(model: model_for(:openai), provider: :openai).with_tools(lookup) }

  def response(city)
    call = RubyLLM::ToolCall.new(provider_call_id: 'call_1', name: 'lookup', arguments: { city: })
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.provider_call_id => call })
  end

  def answer_with(*responses)
    allow(chat.provider).to receive(:complete).and_return(
      *responses, RubyLLM::Message.new(role: :assistant, content: 'Done')
    )
  end

  it 'executes each new invocation and pairs it with its own result' do
    first = response('Paris')
    second = response('London')
    answer_with(first, second)

    expect(chat.ask('Check both cities').content).to eq('Done')
    expect(executions).to eq(%w[Paris London])
    first, second = chat.messages.select(&:tool_call?)
    expect(first.tool_results.map(&:content)).to eq(['Weather in Paris'])
    expect(second.tool_results.map(&:content)).to eq(['Weather in London'])
    expect(chat.provider).to have_received(:complete).exactly(3).times
  end

  it 'distinguishes repeated IDs in messages appended by the application' do
    chat.add_message(response('Paris'))
    chat.run_tools
    chat.add_message(response('London'))
    chat.run_tools

    expect(executions).to eq(%w[Paris London])
  end

  it 'pairs an appended result with the latest call that reused its provider ID' do
    chat.with_model(model_for(:openai), provider: :openai, protocol: :responses)
    %w[Paris London].each do |city|
      chat.add_message(response(city))
      chat.add_message(role: :tool, content: "Weather in #{city}", tool_call_id: 'call_1')
    end
    chat.add_message(role: :assistant, content: 'Done')

    first, second = chat.messages.select(&:tool_call?)
    expect(first.tool_results.map(&:content)).to eq(['Weather in Paris'])
    expect(second.tool_results.map(&:content)).to eq(['Weather in London'])
    results = chat.render[:input].select { |item| item[:type] == 'function_call_output' }
    expect(results.map { |item| item[:call_id] }).to eq(%w[call_1 call_1])
    expect(results.map { |item| item[:output] }).to eq(['Weather in Paris', 'Weather in London'])
  end

  it 'does not carry a one-time approval to a new invocation with identical arguments' do
    lookup.requires_approval
    answer_with(response('Paris'), response('Paris'))
    chat.ask('Check twice')
    first = chat.pending_approvals.first
    chat.approve(first)
    chat.complete

    expect(executions).to eq(['Paris'])
    expect(chat).to be_awaiting_approval
    second = chat.pending_approvals.first
    expect(second.id).not_to eq(first.id)

    chat.approve(first.id)
    chat.complete
    expect(executions).to eq(['Paris'])

    chat.approve(second)
    expect(chat.complete.content).to eq('Done')
    expect(executions).to eq(%w[Paris Paris])
  end

  it 'preserves identities when a partially answered conversation is restored' do
    answer_with(response('Paris'), response('London'))
    chat.ask_later('Check both cities')
    chat.generate
    chat.run_tools
    chat.generate
    ids = chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.keys }

    restored = RubyLLM.chat(model: model_for(:openai), provider: :openai).with_tools(lookup)
    restored.messages = chat.messages.map(&:to_h)
    restored.run_tools.run_tools

    expect(executions).to eq(%w[Paris London])
    expect(restored.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.keys }).to eq(ids)
  end

  it 'replays the provider IDs while keeping the invocations distinct locally' do
    chat.with_model(model_for(:openai), provider: :openai, protocol: :responses)
    answer_with(response('Paris'), response('London'))
    chat.ask('Check both cities')

    payload = chat.render
    calls = payload[:input].select { |item| item[:type] == 'function_call' }
    results = payload[:input].select { |item| item[:type] == 'function_call_output' }

    expect(calls.map { |item| item[:call_id] }).to eq(%w[call_1 call_1])
    expect(results.map { |item| item[:call_id] }).to eq(%w[call_1 call_1])
    expect(results.map { |item| item[:output] }).to eq(['Weather in Paris', 'Weather in London'])
    expect(chat.messages.select(&:tool_call?).flat_map { |message| message.tool_calls.keys }.uniq.size).to eq(2)
  end

  it 'uses the same invocation ID in streamed chunks, callbacks and results' do
    chunks = []
    callbacks = []
    replies = %w[Paris London]
    allow(chat.provider).to receive(:complete) do |*, &block|
      city = replies.shift
      if city
        accumulator = RubyLLM::Protocol::StreamAccumulator.new
        call = response(city).tool_calls.values.first
        chunk = RubyLLM::Chunk.new(role: :assistant, content: '', tool_calls: { 0 => call })
        accumulator.add(chunk)
        block.call(chunk)
        accumulator.to_message(nil)
      else
        block.call(RubyLLM::Chunk.new(role: :assistant, content: 'Done'))
        RubyLLM::Message.new(role: :assistant, content: 'Done')
      end
    end
    chat.before_tool_call { |call| callbacks << call.id }

    chat.ask('Check both cities') { |chunk| chunks.concat(chunk.tool_calls.values.map(&:id)) if chunk.tool_call? }

    expect(executions).to eq(%w[Paris London])
    expect(chunks.size).to eq(2)
    expect(chunks.uniq.size).to eq(2)
    expect(callbacks).to eq(chunks)
    expect(chat.messages.select(&:tool_result?).map(&:tool_call_id)).to eq(chunks)
  end

  it 'does not change an earlier invocation when a provider returns the same message object again' do
    repeated = response('Paris')
    answer_with(repeated, repeated)
    chat.ask('Check twice')

    first, second = chat.messages.select(&:tool_call?)
    expect(executions).to eq(%w[Paris Paris])
    expect(first.tool_results.size).to eq(1)
    expect(second.tool_results.size).to eq(1)
    expect(first.tool_calls.keys).not_to eq(second.tool_calls.keys)
    expect(repeated.tool_calls.keys).to eq(['call_1'])
  end

  it 'pairs a manually supplied result with the provider call' do
    chat.with_model(model_for(:openai), provider: :openai, protocol: :responses)
    answer_with(response('Paris'))
    chat.ask_later('Check Paris')
    call = chat.generate.tool_calls.values.first
    chat.add_message(role: :tool, content: 'Sunny', tool_call_id: call.id)

    expect(chat.render[:input].last).to include(type: 'function_call_output', call_id: 'call_1', output: 'Sunny')
  end

  it 'keeps remote approvals separate while replaying their original IDs and content' do
    chat.with_model(model_for(:openai), provider: :openai, protocol: :responses)
    raw = [{ 'type' => 'mcp_approval_request', 'id' => 'approval_1', 'name' => 'lookup', 'arguments' => '{}' }]
    responses = Array.new(2) do
      call = RubyLLM::ToolCall.new(id: 'approval_1', name: 'lookup', remote: true)
      RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call }, raw_content: raw)
    end
    answer_with(*responses)
    chat.ask('Look up both')
    chat.approve(chat.pending_approvals.first).complete

    expect(chat).to be_awaiting_approval
    chat.deny(chat.pending_approvals.first)
    chat.complete

    expect(executions).to be_empty
    expect(chat.messages.select(&:tool_call?).map(&:raw_content)).to eq([raw, raw])
    decisions = chat.render[:input].select { |item| item[:type] == 'mcp_approval_response' }
    expect(decisions).to eq([
                              { type: 'mcp_approval_response', approval_request_id: 'approval_1', approve: true },
                              { type: 'mcp_approval_response', approval_request_id: 'approval_1', approve: false }
                            ])
  end
end
