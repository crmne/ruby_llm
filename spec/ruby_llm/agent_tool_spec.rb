# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::AgentTool do
  include_context 'with configured RubyLLM'

  let(:sub_requests) { [] }
  let(:sub_answers) { [] }
  let(:research_agent) do
    stub_const('ResearchAgent', Class.new(RubyLLM::Agent) do
      description 'Researches a question and reports back'
      inputs :region
      instructions { "Research for #{region}." }
    end)
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def calling(name, arguments, id: 'call_1')
    RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
                         tool_calls: { id => RubyLLM::ToolCall.new(id:, name:, arguments:) })
  end

  def stub_subagents(agent_class)
    allow(agent_class).to receive(:new).and_wrap_original do |new, **kwargs|
      new.call(**kwargs).tap do |agent|
        allow(agent.chat.provider).to receive(:complete) do |messages, **|
          sub_requests << [RubyLLM::Accounting::Usage.owner, messages.map { |message| message.content.to_s }]
          sub_answers.shift || answer('Ruby 4.0 shipped in December.')
        end
      end
    end
  end

  def parent_chat(*responses)
    RubyLLM.chat(model: model_for(:anthropic)).tap do |chat|
      allow(chat.provider).to receive(:complete).and_return(*responses)
    end
  end

  describe 'Agent.to_tool' do
    it 'names the tool after the agent, with its description, a task, and the inputs it was not given' do
      tool = research_agent.to_tool

      expect(tool).to be_a(described_class)
      expect(tool.name).to eq('research_agent')
      expect(tool.description).to eq('Researches a question and reports back')
      expect(tool.parameters_schema['properties'].keys).to eq(%w[task region])
      expect(tool.parameters_schema['required']).to eq(%w[task region])
      expect(research_agent.to_tool(region: 'EU').parameters_schema['properties'].keys).to eq(%w[task])
    end

    it 'describes an agent without a description by its name' do
      stub_const('PlainAgent', Class.new(RubyLLM::Agent))

      expect(PlainAgent.to_tool.description).to include('PlainAgent')
    end

    it 'refuses an agent class without a name' do
      expect { Class.new(RubyLLM::Agent).to_tool }.to raise_error(ArgumentError, /class name/)
    end

    it 'refuses an agent with an input named task, which the tool takes for the prompt' do
      stub_const('TaskAgent', Class.new(RubyLLM::Agent) { inputs :task })

      expect { TaskAgent.to_tool }.to raise_error(ArgumentError, /task/)
    end

    it 'keeps the namespace in the name, so namespaced agents stay apart' do
      stub_const('Billing', Module.new)
      stub_const('Billing::ResearchAgent', Class.new(RubyLLM::Agent))

      expect(Billing::ResearchAgent.to_tool.name).to eq('billing_research_agent')
    end
  end

  it 'runs a fresh agent on the task with the inputs, and returns its answer to the chat' do
    stub_subagents(research_agent)
    chat = parent_chat(calling('research_agent', { 'task' => 'What changed in Ruby 4.0?', 'region' => 'EU' }),
                       answer('It shipped in December.'))

    chat.with_tools(research_agent).ask('Tell me about Ruby 4.0')

    expect(sub_requests.sole.last).to eq(['Research for EU.', 'What changed in Ruby 4.0?'])
    expect(chat.messages.find(&:tool_result?).content).to eq('Ruby 4.0 shipped in December.')
    expect(chat.messages.last.content).to eq('It shipped in December.')
  end

  it 'runs under the owner of the chat that called it' do
    stub_subagents(research_agent)
    chat = parent_chat(calling('research_agent', { 'task' => 'Look it up', 'region' => 'EU' }), answer('Done'))

    chat.with_owner(:alice).with_tools(research_agent.to_tool).ask('Go')

    expect(sub_requests.sole.first).to eq(:alice)
  end

  it 'runs under the owner of the calling chat even when the agent declares its own' do
    research_agent.owner(:house)
    stub_subagents(research_agent)
    chat = parent_chat(calling('research_agent', { 'task' => 'Look it up', 'region' => 'EU' }), answer('Done'))

    chat.with_owner(:alice).with_tools(research_agent).ask('Go')

    expect(sub_requests.sole.first).to eq(:alice)
  end

  it 'goes wherever tools go, such as another agent' do
    stub_subagents(research_agent)
    lead = Class.new(RubyLLM::Agent) { tools ResearchAgent.to_tool(region: 'US') }
    agent = lead.new
    allow(agent.chat.provider).to receive(:complete)
      .and_return(calling('research_agent', { 'task' => 'Look it up' }), answer('Done'))

    agent.ask('Go')

    expect(agent.tools.keys).to eq([:research_agent])
    expect(sub_requests.sole.last.first).to eq('Research for US.')
  end

  it 'takes an agent class in tools, as well' do
    stub_subagents(research_agent)
    lead = Class.new(RubyLLM::Agent) { tools ResearchAgent }

    expect(lead.new.tools.keys).to eq([:research_agent])
  end

  context 'when the agent stops to wait' do
    let(:guide) { 'https://rubyllm.com/agents/#subagents-that-wait-for-a-person' }

    def tool_named(name, &execute)
      Class.new(RubyLLM::Tool) do
        description "The #{name} tool"
        define_method(:name) { name }
        define_method(:execute, &execute)
      end
    end

    def ask_stopping_agent(*sub_turns)
      stub_subagents(research_agent)
      sub_answers.push(*sub_turns)
      chat = parent_chat(calling('research_agent', { 'task' => 'Clean up', 'region' => 'EU' }), answer('All done'))
      [chat, -> { chat.with_tools(research_agent).ask('Clean up') }]
    end

    it 'raises for the developer, naming the agent and the approval, and the model never hears of it' do
      research_agent.tools(tool_named('wipe') { 'wiped' }.tap(&:requires_approval))
      chat, asking = ask_stopping_agent(calling('wipe', {}, id: 'sub_1'))

      expect(&asking).to raise_error(RubyLLM::ConfigurationError,
                                     'ResearchAgent stopped to wait for a person to approve wipe, but an agent ' \
                                     'used as a tool has to finish within its call. To let it wait, give it a ' \
                                     "chat of its own: #{guide}")
      expect(chat.provider).to have_received(:complete).once
      expect(chat.messages.none?(&:tool_result?)).to be(true)
    end

    it 'names the question a tool of the agent asks' do
      research_agent.tools(tool_named('lookup') { ask('Which order?') })
      _chat, asking = ask_stopping_agent(calling('lookup', {}, id: 'sub_1'))

      expect(&asking).to raise_error(RubyLLM::ConfigurationError,
                                     /\AResearchAgent stopped to wait for a person to answer lookup, but /)
    end

    it 'names the task the agent waits on, and everything else it waits for' do
      research_agent.tools(tool_named('render') { RubyLLM::Task.new(status: :working) },
                           tool_named('wipe') { 'wiped' }.tap(&:requires_approval))
      both = RubyLLM::Message.new(role: :assistant, content: '', input_tokens: 1, output_tokens: 1, tool_calls: {
                                    'sub_1' => RubyLLM::ToolCall.new(id: 'sub_1', name: 'render', arguments: {}),
                                    'sub_2' => RubyLLM::ToolCall.new(id: 'sub_2', name: 'wipe', arguments: {})
                                  })
      _chat, asking = ask_stopping_agent(both)

      waits = 'a person to approve wipe and the task of render'
      expect(&asking).to raise_error(RubyLLM::ConfigurationError, /\AResearchAgent stopped to wait for #{waits},/)
    end
  end
end
