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

  context 'when a later job runs a stopped chat' do
    before do
      record.with_tools(stop_tool)
      allow(record.to_llm.provider).to receive(:complete).and_return(round)
      begin
        record.ask('Go')
      rescue RubyLLM::CancelledError
        nil
      end
    end

    def reloaded
      @reloaded ||= Chat.find(record.id).with_tools(stop_tool).tap do |chat|
        allow(chat.to_llm.provider).to receive(:complete).and_return(answer)
      end
    end

    it 'does not resume the stopped turn' do
      reloaded.complete

      expect(reloaded.to_llm.provider).not_to have_received(:complete)
      expect(reloaded).to be_complete
    end

    it 'answers a message queued meanwhile' do
      reloaded.queue('Use the EU file')

      expect(reloaded.complete.content).to eq('Done')

      expect(reloaded.to_llm.provider).to have_received(:complete).once
      expect(reloaded.messages.where(role: 'user').order(:id).last.content).to eq('Use the EU file')
    end
  end
end
