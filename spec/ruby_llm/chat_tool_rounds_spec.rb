# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(lookup) }

  let(:lookup) do
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'lookup' }
      define_method(:execute) { 'found' }
    end
  end

  let(:charge) do
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'charge' }
      requires_approval
      define_method(:execute) { 'charged' }
    end
  end

  let(:conclude) do
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'conclude' }
      define_method(:execute) { halt 'Filed' }
    end
  end

  def calls(*names)
    tool_calls = names.to_h do |name|
      id = "call_#{SecureRandom.hex(4)}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def looping(chat)
    replies = Array.new(12) { calls('lookup') }
    allow(chat.provider).to receive(:complete) { replies.shift || raise('The loop did not stop') }
  end

  def requests
    RSpec::Mocks.space.proxy_for(chat.provider).messages_arg_list.count
  end

  describe 'with_tool_options(rounds:)' do
    it 'is off by default' do
      expect(described_class.new(model: model_for(:anthropic)).tool_options[:rounds]).to be_nil
    end

    it 'keeps the limit beside the other options and returns the chat' do
      expect(chat.with_tool_options(rounds: 25, calls: :one)).to be(chat)
      expect(chat.tool_options).to include(rounds: 25, calls: :one)
    end

    it 'carries over to a copy of the chat' do
      expect(chat.with_tool_options(rounds: 25).dup.tool_options[:rounds]).to eq(25)
    end

    it 'leaves the limit alone when another option changes' do
      chat.with_tool_options(rounds: 25).with_tool_options(calls: :one)

      expect(chat.tool_options[:rounds]).to eq(25)
    end

    it 'resets with nil' do
      chat.with_tool_options(rounds: 1).with_tool_options(rounds: nil)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup'), calls('lookup'), answer)

      expect(chat.ask('Go').content).to eq('done')
      expect(chat.tool_options[:rounds]).to be_nil
    end

    [0, -1, 1.5, '25', :many, true].each do |value|
      it "refuses #{value.inspect}" do
        expect { chat.with_tool_options(rounds: value) }
          .to raise_error(ArgumentError, "Invalid rounds value: #{value.inspect}. Valid values are positive integers")
      end
    end

    it 'names rounds among the valid options' do
      expect { chat.with_tool_options(nope: 1) }
        .to raise_error(ArgumentError, /\AUnknown tool option: nope\. Valid options are: .*\brounds\z/)
    end

    it 'stays out of what the provider receives' do
      allow(chat.provider).to receive(:complete).and_return(answer)

      chat.with_tool_options(rounds: 2).ask('Go')

      expect(chat.provider).to have_received(:complete)
        .with(anything, hash_including(tool_prefs: { choice: nil, calls: nil }))
    end
  end

  describe 'the limit' do
    it 'lets the loop run past 25 rounds without one' do
      replies = Array.new(40) { calls('lookup') } << answer
      allow(chat.provider).to receive(:complete).and_return(*replies)

      expect(chat.ask('Go').content).to eq('done')
      expect(requests).to eq(41)
    end

    it 'stops after the last round and before the next model call' do
      looping(chat.with_tool_options(rounds: 3))

      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)
      expect(requests).to eq(3)
    end

    it 'says the limit and how to continue' do
      looping(chat.with_tool_options(rounds: 3))

      expect { chat.ask('Go') }.to raise_error(
        RubyLLM::ToolRoundLimitError,
        'Reached the tool round limit (3). Every tool call has its result, so call complete to continue, ' \
        'or raise the limit with with_tool_options(rounds:).'
      )
    end

    it 'is not a failed provider request' do
      expect(RubyLLM::ToolRoundLimitError.superclass).to eq(StandardError)
    end

    it 'leaves no tool call unanswered' do
      looping(chat.with_tool_options(rounds: 2))

      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)

      expect(chat.messages.map(&:role)).to eq(%i[user assistant tool assistant tool])
      expect(chat).not_to be_waiting
      expect(chat).not_to be_complete
    end

    it 'counts a response with several calls as one round' do
      allow(chat.with_tool_options(rounds: 2).provider).to receive(:complete)
        .and_return(calls('lookup', 'lookup', 'lookup'), calls('lookup'), answer)

      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)
      expect(requests).to eq(2)
      expect(chat.messages.count(&:tool_result?)).to eq(4)
    end

    it 'lets the model answer within the limit' do
      allow(chat.with_tool_options(rounds: 2).provider).to receive(:complete).and_return(calls('lookup'), answer)

      expect(chat.ask('Go').content).to eq('done')
    end

    it 'does not count a reply without tool calls' do
      allow(chat.with_tool_options(rounds: 1).provider).to receive(:complete).and_return(answer)

      chat.ask('First')

      expect(chat.ask('Second').content).to eq('done')
    end

    it 'does not count a reply without tool calls when a queued message goes on with the turn' do
      replies = [answer, answer]
      allow(chat.with_tool_options(rounds: 1).provider).to receive(:complete) do
        chat.queue('Use the EU file') if replies.size == 2
        replies.shift
      end

      expect(chat.ask('Go').content).to eq('done')
      expect(requests).to eq(2)
    end

    it 'ends the turn when a tool halts on the last round' do
      chat.with_tools(conclude).with_tool_options(rounds: 1)
      allow(chat.provider).to receive(:complete).and_return(calls('conclude'))

      expect(chat.ask('Go').content).to eq('Filed')
    end

    it 'keeps a queued message for the next complete' do
      looping(chat.with_tool_options(rounds: 1))
      chat.after_tool_result { chat.queue('Use the EU file') if chat.queued_messages.empty? }

      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)
      expect(chat.queued_messages.map(&:content)).to eq(['Use the EU file'])
    end
  end

  describe 'counting' do
    it 'starts again on each complete' do
      looping(chat.with_tool_options(rounds: 2))
      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)

      expect { chat.complete }.to raise_error(RubyLLM::ToolRoundLimitError)
      expect(requests).to eq(4)
    end

    it 'lets complete keep going to the answer' do
      allow(chat.with_tool_options(rounds: 1).provider).to receive(:complete).and_return(calls('lookup'), answer)
      expect { chat.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)

      expect(chat.complete.content).to eq('done')
    end

    it 'starts again after a pause for a person, and the answered round does not count' do
      chat.with_tools(charge).with_tool_options(rounds: 2)
      allow(chat.provider).to receive(:complete)
        .and_return(calls('lookup'), calls('charge'), calls('lookup'), calls('lookup'), answer)

      chat.ask('Go')
      expect(chat).to be_waiting
      chat.pending_questions.sole.approve

      expect { chat.complete }.to raise_error(RubyLLM::ToolRoundLimitError)
      expect(requests).to eq(4)
    end

    it 'does not limit a loop driven with step' do
      looping(chat.with_tool_options(rounds: 1))
      chat.ask_later('Go')

      6.times { chat.step }

      expect(chat.messages.count(&:tool_result?)).to eq(3)
    end
  end

  describe 'what complete returns' do
    it 'is the system message of a chat with nothing else' do
      chat.with_instructions('Be terse')

      expect(chat.complete.role).to eq(:system)
    end

    it 'is the last message outside the instructions added after the reply' do
      allow(chat.provider).to receive(:complete).and_return(answer)
      chat.ask('Go')
      chat.with_instructions('Be terse', append: true)

      expect(chat.complete.role).to eq(:assistant)
    end
  end

  describe 'on an agent' do
    let(:agent_class) do
      tool = lookup
      model_id = model_for(:anthropic)
      Class.new(RubyLLM::Agent) do
        model model_id
        tools tool
        tool_options rounds: 2
      end
    end

    it 'takes rounds through the macro' do
      agent = agent_class.new
      expect(agent.tool_options[:rounds]).to eq(2)
      allow(agent.chat.provider).to receive(:complete) { calls('lookup') }

      expect { agent.ask('Go') }.to raise_error(RubyLLM::ToolRoundLimitError)
    end
  end
end
