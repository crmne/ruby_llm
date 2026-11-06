# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }

  let(:conclude) do
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'conclude' }
      define_method(:execute) { halt 'Filed as a bug' }
    end
  end

  let(:conclude_midway) do
    ran = []
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'conclude_midway' }
      define_singleton_method(:ran) { ran }
      define_method(:execute) do
        halt({ status: 'filed' })
        ran << :after_halt
      end
    end
  end

  let(:lookup) do
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'lookup' }
      define_method(:execute) { 'found' }
    end
  end

  def calls(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      ["call_#{index}", RubyLLM::ToolCall.new(id: "call_#{index}", name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer(content = 'done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  it 'ends the turn after the round, without asking the model again' do
    chat.with_tools(conclude)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude'), answer)

    response = chat.ask('Triage this')

    expect(chat.provider).to have_received(:complete).once
    expect(response).to be_tool_result
    expect(response).to be_halted
    expect(response.content).to eq('Filed as a bug')
    expect(chat).to be_complete
    expect(chat).not_to be_waiting
  end

  it 'stops the tool where it calls halt' do
    chat.with_tools(conclude_midway)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude_midway'), answer)

    chat.ask('Triage this')

    expect(conclude_midway.ran).to be_empty
    expect(chat.messages.last.content).to eq('{"status":"filed"}')
    expect(chat).to be_complete
  end

  it 'runs the rest of the round before ending the turn' do
    chat.with_tools(conclude, lookup).with_tool_options(concurrency: :threads)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude', 'lookup'), answer)

    chat.ask('Triage this')

    expect(chat.messages.select(&:tool_result?).map(&:content)).to contain_exactly('Filed as a bug', 'found')
    expect(chat.provider).to have_received(:complete).once
    expect(chat).to be_complete
  end

  it 'returns the halted result when another call of the round finishes after it' do
    chat.with_tools(conclude, lookup)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude', 'lookup'), answer)

    response = chat.ask('Triage this')

    expect(chat.messages.last.content).to eq('found')
    expect(response).to be_halted
    expect(response.content).to eq('Filed as a bug')
  end

  it 'knows the turn ended when the transcript holds only the halted result' do
    chat.add_message(RubyLLM::Message.new(role: :tool, content: 'Filed', tool_call_id: 'call_0',
                                          finish_reason: :halted))

    expect(chat).to be_complete
  end

  it 'returns nil from step and leaves complete alone once halted' do
    chat.with_tools(conclude)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude'), answer)
    chat.ask_later('Triage this')

    chat.step
    chat.step

    expect(chat.step).to be_nil
    expect(chat.complete).to be_halted
    expect(chat.provider).to have_received(:complete).once
  end

  it 'starts a new turn on the next ask, sending the halted result as usual' do
    chat.with_tools(conclude)
    sent = []
    responses = [calls('conclude'), answer('Anything else?')]
    allow(chat.provider).to receive(:complete) do |messages, **|
      sent << messages.map(&:role)
      responses.shift
    end
    chat.ask('Triage this')

    expect(chat.ask('Thanks').content).to eq('Anything else?')
    expect(sent.last).to eq(%i[user assistant tool user])
  end

  it 'takes queued messages after the halted turn, as after an answer' do
    chat.with_tools(conclude)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude'), answer('Next one'))
    chat.ask('Triage this')
    chat.queue('And this one', steer: false)

    expect(chat.complete.content).to eq('Next one')
  end

  it 'leaves a halted chat out of batches, which take chats awaiting the model' do
    chat.with_tools(conclude)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude'), answer)
    chat.ask_later('Triage this')
    chat.step
    chat.run_tools

    expect { RubyLLM.batch(chat) }.to raise_error(ArgumentError, /awaiting the model/)
  end

  it 'keeps halting across a reload of the transcript' do
    chat.with_tools(conclude)
    allow(chat.provider).to receive(:complete).and_return(calls('conclude'), answer)
    chat.ask('Triage this')

    copy = described_class.new(model: model_for(:anthropic))
    chat.messages.each { |message| copy.add_message(RubyLLM::Message.new(message.to_h)) }

    expect(copy).to be_complete
  end
end
