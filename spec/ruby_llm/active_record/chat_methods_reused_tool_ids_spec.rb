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

  def response(city)
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'lookup', arguments: { city: })
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })
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
    expect(second.provider_id).to eq(first.provider_id)
    expect(second.provider_id).to eq('call_1')

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
      expect(chat.pending_approvals.first.provider_id).to eq('call_1')
    end
  end

  it 'distinguishes repeated IDs in messages appended by the application' do
    chat = process(Chat.create!(model: model_for(:openai)))
    first = chat.add_message(response('Paris')).tool_calls.values.first
    chat.approve(first).run_tools
    second = chat.add_message(response('London')).tool_calls.values.first

    expect(second.id).not_to eq(first.id)
    expect(process(chat).pending_approvals.map(&:tool_call_id)).to eq([second.id])
  end
end
