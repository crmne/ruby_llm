# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:lookup) do
    calls = executions
    Class.new(RubyLLM::Tool) do
      requires_approval
      define_method(:name) { 'lookup' }
      define_method(:execute) do |city:|
        calls << city
        "Weather in #{city}"
      end
    end
  end

  def process(chat)
    Chat.find(chat.id).with_tools(lookup).tap { |record| record.protocol = :responses }
  end

  def response(city, id: nil)
    call = RubyLLM::ToolCall.new(id:, provider_call_id: 'call_1', name: 'lookup', arguments: { city: })
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { id || call.provider_call_id => call })
  end

  def results_of(chat)
    RubyLLM::ActiveRecord::ToolCall.where(message: chat.messages).order(:id).map { |call| call.result&.content }
  end

  it 'gives a call appended to another chat its own ID' do
    first, second = Array.new(2) { process(Chat.create!(model: model_for(:openai))) }
    first.add_message(response('Paris', id: 'call_1'))
    call = second.add_message(response('London', id: 'call_1')).tool_calls.values.first
    second.add_message(role: :tool, content: 'Weather in London', tool_call_id: 'call_1')

    expect(call.id).not_to eq('call_1')
    expect(call.provider_call_id).to eq('call_1')
    expect(results_of(first)).to eq([nil])
    expect(results_of(second)).to eq(['Weather in London'])
    expect(process(second).to_llm.messages.last.tool_call_id).to eq(call.id)
  end

  it 'appends message records with tool calls from another chat' do
    first, second = Array.new(2) { process(Chat.create!(model: model_for(:openai))) }
    first.add_message(response('Paris'))
    first.add_message(role: :tool, content: 'Weather in Paris', tool_call_id: 'call_1')
    first.messages.order(:id).each { |record| second.add_message(record) }

    copied = process(second).to_llm.messages
    expect(copied.first.tool_calls.keys).not_to eq(process(first).to_llm.messages.first.tool_calls.keys)
    expect(copied.last.tool_call_id).to eq(copied.first.tool_calls.keys.first)
    expect(results_of(first)).to eq(['Weather in Paris'])
    expect(results_of(second)).to eq(['Weather in Paris'])
  end

  it 'keeps calls, approvals and results separate across processes' do
    chat = process(Chat.create!(model: model_for(:openai)))
    allow(chat.to_llm.provider).to receive(:complete).and_return(response('Paris'))
    chat.ask('Check Paris and London')
    first = chat.pending_approvals.first
    process(chat).approve(first)

    worker = process(chat)
    allow(worker.to_llm.provider).to receive(:complete).and_return(response('London'))
    worker.complete
    second = worker.pending_approvals.first

    expect(executions).to eq(['Paris'])
    expect(second.tool_call_id).not_to eq(first.tool_call_id)
    expect(second.provider_call_id).to eq(first.provider_call_id)
    expect(second.provider_call_id).to eq('call_1')

    process(chat).approve(first.tool_call_id)
    expect(process(chat).pending_approvals.pluck(:id)).to eq([second.id])

    process(chat).approve(second.tool_call_id)
    worker = process(chat)
    allow(worker.to_llm.provider).to receive(:complete)
      .and_return(RubyLLM::Message.new(role: :assistant, content: 'Done'))
    worker.complete

    expect(executions).to eq(%w[Paris London])
    expect(first.reload.result.content).to eq('Weather in Paris')
    expect(second.reload.result.content).to eq('Weather in London')
    results = process(chat).to_llm.render[:input].select { |item| item[:type] == 'function_call_output' }
    expect(results.map { |item| item[:call_id] }).to eq(%w[call_1 call_1])
  end

  it 'accepts the same provider ID in separate chats' do
    2.times do
      chat = process(Chat.create!(model: model_for(:openai)))
      allow(chat.to_llm.provider).to receive(:complete).and_return(response('Paris'))
      chat.ask('Check Paris')
      expect(chat.pending_approvals.first.provider_call_id).to eq('call_1')
    end
  end

  it 'distinguishes repeated IDs in messages appended by the application' do
    id = SecureRandom.uuid
    chat = process(Chat.create!(model: model_for(:openai)))
    first = chat.add_message(response('Paris', id:)).tool_calls.values.first
    chat.approve(first).run_tools
    second = chat.add_message(response('London', id:)).tool_calls.values.first

    expect(second.id).not_to eq(first.id)
    expect(process(chat).pending_approvals.map(&:tool_call_id)).to eq([second.id])
  end

  it 'pairs an appended result with the latest call that reused its provider ID' do
    chat = process(Chat.create!(model: model_for(:openai)))
    %w[Paris London].each do |city|
      chat.add_message(response(city))
      chat.add_message(role: :tool, content: "Weather in #{city}", tool_call_id: 'call_1')
    end
    chat.add_message(role: :assistant, content: 'Done')

    calls = RubyLLM::ActiveRecord::ToolCall.where(message: chat.messages).order(:id)
    expect(calls.map { |call| call.result.content }).to eq(['Weather in Paris', 'Weather in London'])
    results = process(chat).to_llm.render[:input].select { |item| item[:type] == 'function_call_output' }
    expect(results.map { |item| item[:call_id] }).to eq(%w[call_1 call_1])
    expect(results.map { |item| item[:output] }).to eq(['Weather in Paris', 'Weather in London'])
  end

  it 'keeps the first result of a call that is answered again' do
    chat = process(Chat.create!(model: model_for(:openai)))
    call = chat.add_message(response('Paris')).tool_calls.values.first
    chat.add_message(role: :tool, content: 'Weather in Paris', tool_call_id: call.id)
    chat.add_message(role: :tool, content: 'Again', tool_call_id: call.id)

    expect(RubyLLM::ActiveRecord::ToolCall.find_by!(tool_call_id: call.id).result.content).to eq('Weather in Paris')
  end
end
