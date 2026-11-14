# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:executions) { [] }
  let(:chat) { described_class.new(model: model_for(:anthropic)).with_tools(lookup, charge) }

  let(:lookup) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'lookup' }
      define_method(:execute) do
        runs << :lookup
        'found'
      end
    end
  end

  let(:charge) do
    runs = executions
    Class.new(RubyLLM::Tool) do
      define_singleton_method(:tool_name) { 'charge' }
      requires_approval
      define_method(:execute) do
        runs << :charge
        'charged'
      end
    end
  end

  def calls(*names)
    tool_calls = names.each_with_index.to_h do |name, index|
      id = "call_#{index + 1}"
      [id, RubyLLM::ToolCall.new(id:, name:, arguments: {})]
    end
    RubyLLM::Message.new(role: :assistant, content: '', tool_calls:)
  end

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'done', input_tokens: 1, output_tokens: 1)
  end

  def response_ids(chat)
    chat.messages.find(&:tool_call?).tool_calls.map(&:id)
  end

  def results(chat)
    contents = chat.messages.select(&:tool_result?).to_h { |message| [message.tool_call_id, message.content] }
    response_ids(chat).map { |id| contents[id] }
  end

  def capped_error(cap)
    { error: "This call didn't run: too many tool calls in one answer (#{cap} at most). " \
             'Continue step by step, a few calls at a time.' }.to_json
  end

  def recorded_events(name)
    events = []
    instrumenter = Class.new do
      define_method(:instrument) do |event, payload = {}, &block|
        events << payload if event == name
        block&.call(payload)
      end
    end.new
    allow(RubyLLM.config).to receive(:instrumenter).and_return(instrumenter)
    events
  end

  describe 'with_tool_options(calls:) with a number' do
    it 'is off by default' do
      expect(described_class.new(model: model_for(:anthropic)).tool_options[:calls]).to be_nil
    end

    it 'keeps the cap beside the other options and returns the chat' do
      expect(chat.with_tool_options(rounds: 25, calls: 50)).to be(chat)
      expect(chat.tool_options).to include(rounds: 25, calls: 50)
    end

    it 'carries over to a copy of the chat' do
      expect(chat.with_tool_options(calls: 50).dup.tool_options[:calls]).to eq(50)
    end

    it 'leaves the cap alone when another option changes' do
      chat.with_tool_options(calls: 50).with_tool_options(rounds: 3)

      expect(chat.tool_options[:calls]).to eq(50)
    end

    it 'replaces calls: :one, and is replaced by it' do
      chat.with_tool_options(calls: :one).with_tool_options(calls: 2)
      expect(chat.tool_options[:calls]).to eq(2)

      chat.with_tool_options(calls: :one)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)
      chat.ask('Go')

      expect(executions).to eq(%i[lookup lookup lookup])
    end

    it 'keeps calls: 1 as calls: :one' do
      expect(chat.with_tool_options(calls: 1).tool_options[:calls]).to eq(:one)
    end

    it 'resets with nil' do
      chat.with_tool_options(calls: 2).with_tool_options(calls: nil)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(executions).to eq(%i[lookup lookup lookup])
      expect(chat.tool_options[:calls]).to be_nil
    end

    [0, -1, 1.5, '25', true].each do |value|
      it "refuses #{value.inspect}" do
        expect { chat.with_tool_options(calls: value) }
          .to raise_error(ArgumentError,
                          "Invalid calls value: #{value.inspect}. Valid values are: :many, :one, or a positive integer")
      end
    end

    it 'keeps the options it had when it refuses a value' do
      chat.with_tool_options(calls: 50)

      expect { chat.with_tool_options(calls: 0) }.to raise_error(ArgumentError)
      expect(chat.tool_options[:calls]).to eq(50)
    end

    it 'stays out of what the provider receives' do
      allow(chat.provider).to receive(:complete).and_return(answer)

      chat.with_tool_options(calls: 2).ask('Go')

      expect(chat.provider).to have_received(:complete)
        .with(anything, hash_including(tool_prefs: { choice: nil, calls: nil }))
    end
  end

  describe 'the cap' do
    it 'runs every call without one' do
      allow(chat.provider).to receive(:complete).and_return(calls(*Array.new(40, 'lookup')), answer)

      chat.ask('Go')

      expect(executions.size).to eq(40)
    end

    it 'asks for approval of every call without one' do
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'charge', 'charge'), answer)

      chat.ask('Go')

      expect(chat.pending_questions.map(&:id)).to eq(response_ids(chat).last(2))
    end

    it 'runs the calls within it and answers the rest with an error, in the response order' do
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      expect(chat.ask('Go').content).to eq('done')

      expect(executions).to eq(%i[lookup lookup])
      expect(results(chat)).to eq(['found', 'found', capped_error(2)])
    end

    it 'sends the model a result for every call' do
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      sent = RSpec::Mocks.space.proxy_for(chat.provider).messages_arg_list.last.first
      expect(sent.select(&:tool_result?).map(&:tool_call_id)).to eq(response_ids(chat))
    end

    it 'leaves a response within it alone' do
      chat.with_tool_options(calls: 3)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(executions.size).to eq(3)
      expect(results(chat)).to all(eq('found'))
    end

    it 'runs no callbacks for a capped call but adds its message' do
      tools = []
      added = []
      started = 0
      chat.with_tool_options(calls: 2)
          .before_tool_call { |call| tools << call.id }
          .before_message { started += 1 }
          .after_message { |message| added << message.tool_call_id if message.tool_result? }
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(tools).to eq(response_ids(chat).first(2))
      expect(added).to eq(response_ids(chat))
      expect(started).to eq(chat.messages.count { |message| message.role != :user })
    end

    it 'asks no question for an approval-required call past it' do
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'charge'), answer)

      expect(chat.ask('Go').content).to eq('done')

      expect(chat).not_to be_waiting
      expect(chat.pending_questions).to be_empty
      expect(executions).to eq(%i[lookup lookup])
      expect(results(chat).last).to eq(capped_error(2))
    end

    it 'shows no question for a capped call before the tools run' do
      chat.with_tool_options(calls: 2).add_message(role: :user, content: 'Go')
      chat.add_message(calls('lookup', 'lookup', 'charge'))

      expect(chat.pending_questions).to be_empty
      expect(chat).not_to be_waiting
    end

    it 'shows the question for a call within it before the tools run' do
      chat.with_tool_options(calls: 2).add_message(role: :user, content: 'Go')
      chat.add_message(calls('charge', 'lookup', 'lookup'))

      expect(chat.pending_questions.map(&:id)).to eq(response_ids(chat).first(1))
    end

    it 'stops answering capped calls once the chat is cancelled' do
      chat.with_tool_options(calls: 2).after_tool_result { chat.cancel if executions.size == 2 }
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      expect { chat.ask('Go') }.to raise_error(RubyLLM::CancelledError)
      expect(results(chat).last).not_to eq(capped_error(2))
    end

    it 'records no denial for a capped call' do
      state = RubyLLM::Chat::ToolCallState.new.tap { |fresh| chat.tool_call_state = fresh }
      allow(state).to receive(:record_decision).and_call_original
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'charge'), answer)

      chat.ask('Go')

      expect(state).not_to have_received(:record_decision)
      expect(state.decision(chat.messages.find(&:tool_call?).tool_calls.to_a.last)).to be_nil
    end

    it 'claims only the calls within it' do
      state = RubyLLM::Chat::ToolCallState.new.tap { |fresh| chat.tool_call_state = fresh }
      allow(state).to receive(:claim).and_call_original
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      within = response_ids(chat).first(2)
      expect(state).to have_received(:claim).with(within, executing: within)
    end

    it 'still asks for approval of a call within it' do
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('charge', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(chat).to be_waiting
      expect(chat.pending_questions.map(&:id)).to eq(response_ids(chat).first(1))
      expect(results(chat)).to eq([nil, 'found', capped_error(2)])

      chat.pending_questions.sole.approve
      expect(chat.complete.content).to eq('done')
      expect(executions).to eq(%i[lookup charge])
    end

    it 'counts each response on its own' do
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete)
        .and_return(calls('lookup', 'lookup', 'lookup'), calls('lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(executions.size).to eq(4)
    end
  end

  describe 'the tool_calls_capped.ruby_llm event' do
    it 'fires with the counts and the chat' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup', 'lookup', 'lookup'),
                                                            answer)

      chat.ask('Go')

      expect(events.sole).to include(chat:, provider: chat.provider.slug, model: chat.model.id,
                                     requested: 5, allowed: 2, capped: 3)
      expect(events.sole).not_to include(:agent_name, :chat_id)
    end

    it 'names the fallback that wrote the response' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      chat.with_tool_options(calls: 2)
      response = calls('lookup', 'lookup', 'lookup').stood_in(model: 'fallback-model', provider: 'openai')
      allow(chat.provider).to receive(:complete).and_return(response, answer)

      chat.ask('Go')

      expect(events.sole).to include(provider: 'openai', model: 'fallback-model')
    end

    it 'fires after every capped call has its result' do
      results_at_event = nil
      instrumenter = Class.new do
        define_method(:instrument) do |name, payload = {}, &block|
          results_at_event = payload[:chat].messages.count(&:tool_result?) if name == 'tool_calls_capped.ruby_llm'
          block&.call(payload)
        end
      end.new
      allow(RubyLLM.config).to receive(:instrumenter).and_return(instrumenter)
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(results_at_event).to eq(4)
    end

    it 'fires once when a callback stopped the answers and complete finishes them' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      raised = false
      chat.with_tool_options(calls: 2).after_message do |message|
        if message.tool_result? && message.content.include?("didn't run") && !raised
          raised = true
          raise 'boom'
        end
      end
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup', 'lookup'), answer)

      expect { chat.ask('Go') }.to raise_error('boom')
      chat.complete

      expect(events.size).to eq(1)
      expect(events.sole).to include(capped: 2)
    end

    it 'does not fire within the cap' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup'), answer)

      chat.ask('Go')

      expect(events).to be_empty
    end

    it 'fires once, not again when the round continues after an approval' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      chat.with_tool_options(calls: 2)
      allow(chat.provider).to receive(:complete).and_return(calls('charge', 'lookup', 'lookup'), answer)

      chat.ask('Go')
      chat.pending_questions.sole.approve
      chat.complete

      expect(events.size).to eq(1)
    end
  end

  describe 'on an agent' do
    let(:agent_class) do
      tool = lookup
      model_id = model_for(:anthropic)
      stub_const('CappedAgent', Class.new(RubyLLM::Agent) do
        model model_id
        tools tool
        tool_options calls: 2
      end)
    end

    it 'takes the cap through the macro' do
      agent = agent_class.new
      expect(agent.tool_options[:calls]).to eq(2)
      allow(agent.chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      agent.ask('Go')

      expect(executions.size).to eq(2)
      expect(results(agent.chat).last).to eq(capped_error(2))
    end

    it 'names the agent in the event' do
      events = recorded_events('tool_calls_capped.ruby_llm')
      agent = agent_class.new
      allow(agent.chat.provider).to receive(:complete).and_return(calls('lookup', 'lookup', 'lookup'), answer)

      agent.ask('Go')

      expect(events.sole).to include(agent_name: 'CappedAgent', requested: 3, allowed: 2, capped: 1)
    end
  end
end
