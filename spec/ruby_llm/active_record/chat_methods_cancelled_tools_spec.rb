# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:runs) { [] }
  let(:record) { Chat.create!(model: model_for(:openai)) }
  let(:stop_tool) do
    ran = runs
    owner = -> { record }
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'stop' }
      define_method(:execute) do
        ran << :stop
        owner.call.cancel
        'stopped'
      end
    end
  end
  let(:round) do
    calls = %w[call_1 call_2].to_h { |id| [id, RubyLLM::ToolCall.new(id:, name: 'stop', arguments: {})] }
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls: calls, input_tokens: 1, output_tokens: 1)
  end
  let(:answer) { RubyLLM::Message.new(role: :assistant, content: 'Done', input_tokens: 1, output_tokens: 1) }

  it 'persists the finished result and the closed call, so another process goes on' do
    record.with_tools(stop_tool)
    allow(record.to_llm.provider).to receive(:complete).and_return(round)

    expect { record.ask('Go') }.to raise_error(RubyLLM::CancelledError)

    reloaded = Chat.find(chat_id = record.id).with_tools(stop_tool)
    allow(reloaded.to_llm.provider).to receive(:complete).and_return(answer)
    results = reloaded.messages.where(role: 'tool').order(:id).map(&:content)
    expect(results.first).to eq('stopped')
    expect(results.last).to include('did not finish')
    expect(reloaded.ask('Never mind').content).to eq('Done')
    expect(runs).to eq([:stop])
    expect(Chat.find(chat_id).messages.where(role: 'tool').count).to eq(2)
  end
end
