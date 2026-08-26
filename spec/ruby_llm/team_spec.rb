# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Team do
  def coworker_class(response: 'done')
    Class.new do
      define_method :ask do |prompt|
        RubyLLM::Message.new(role: :assistant, content: "#{response}: #{prompt}")
      end
    end
  end

  describe '#add' do
    it 'returns itself for chaining' do
      team = described_class.new

      expect(team.add(:researcher, coworker_class)).to equal(team)
    end

    it 'requires a role and an agent' do
      team = described_class.new

      expect { team.add('', coworker_class) }.to raise_error(ArgumentError, 'provide a role')
      expect { team.add(:researcher, nil) }.to raise_error(ArgumentError, 'provide an agent')
    end

    it 'replaces a coworker registered under the same role' do
      team = described_class.new
      team.add(:researcher, coworker_class(response: 'first'))
      team.add(:researcher, coworker_class(response: 'second'))

      result = team.collaboration_tools.first.call({ 'task' => 'check', 'coworker' => 'researcher' })

      expect(result).to eq('second: check')
    end

    it 'detaches a string role from its caller' do
      role = +'researcher'
      team = described_class.new.add(role, coworker_class)
      role.replace('writer')

      result = team.collaboration_tools.first.call({ 'task' => 'check', 'coworker' => 'researcher' })

      expect(result).to eq('done: check')
    end
  end

  describe '#collaboration_tools' do
    def stateful_coworker
      Class.new do
        def initialize
          @log = []
        end

        def ask(prompt)
          @log << prompt
          RubyLLM::Message.new(role: :assistant, content: "#{@log.size}:#{prompt}")
        end
      end
    end

    def team_with(coworker)
      described_class.new.add(:researcher, coworker)
    end

    let(:team) { team_with(stateful_coworker) }
    let(:tools) { team.collaboration_tools }
    let(:delegate_tool) { tools.first }
    let(:ask_tool) { tools.last }

    it 'returns delegation and question tools' do
      expect(team.collaboration_tools.map(&:name)).to eq(%w[delegate_work ask_question])
    end

    it 'lists the available coworker roles in each tool description' do
      team.add(:writer, coworker_class)
      delegate, ask = team.collaboration_tools

      expect(delegate.description).to end_with('Coworkers: researcher, writer')
      expect(ask.description).to end_with('Coworkers: researcher, writer')
    end

    it 'keeps context optional in the argument schemas' do
      expect(delegate_tool.parameters_schema['required']).to eq(%w[coworker task])
      expect(ask_tool.parameters_schema['required']).to eq(%w[coworker question])
      expect(delegate_tool.parameters_schema['properties']).to have_key('context')
    end

    it 'delegates work and asks questions' do
      delegated = delegate_tool.call({ 'task' => 'Summarize X', 'coworker' => 'researcher' })
      answered = ask_tool.call({ 'question' => 'How big is X?', 'coworker' => 'researcher' })

      expect(delegated).to eq('1:Summarize X')
      expect(answered).to eq('1:How big is X?')
    end

    it 'returns plain coworker replies as-is' do
      coworker = Class.new do
        def ask(_prompt) = 'plain reply'
      end

      result = team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'check', 'coworker' => 'researcher' }
      )

      expect(result).to eq('plain reply')
    end

    it 'reads content from replies without attachments' do
      reply = Struct.new(:content).new('content only')
      coworker = Class.new do
        define_method(:ask) { |_prompt| reply }
      end

      result = team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'check', 'coworker' => 'researcher' }
      )

      expect(result).to eq('content only')
    end

    it 'appends shared context to the coworker prompt' do
      prompts = []
      coworker = Class.new do
        define_method(:ask) do |prompt|
          prompts << prompt
          RubyLLM::Message.new(role: :assistant, content: 'ok')
        end
      end

      team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'Summarize X', 'coworker' => 'researcher', 'context' => 'for an intro' }
      )

      expect(prompts).to eq(["Summarize X\n\nContext: for an intro"])
    end

    it 'instantiates registered classes fresh for every delegation' do
      delegate = team_with(stateful_coworker).collaboration_tools.first

      delegate.call({ 'task' => 'first', 'coworker' => 'researcher' })

      expect(delegate.call({ 'task' => 'second', 'coworker' => 'researcher' })).to eq('1:second')
    end

    it 'reuses a registered instance between delegations' do
      team = described_class.new.add(:writer, stateful_coworker.new)
      delegate = team.collaboration_tools.first

      expect(delegate.call({ 'task' => 'first', 'coworker' => 'writer' })).to eq('1:first')
      expect(delegate.call({ 'task' => 'second', 'coworker' => 'writer' })).to eq('2:second')
    end

    it 'returns an error that names available coworkers for an unknown role' do
      result = delegate_tool.call({ 'task' => 'Summarize X', 'coworker' => 'nobody' })

      expect(result[:error]).to eq("Unknown coworker 'nobody'. Available: researcher")
    end

    it 'returns a recoverable error when a coworker raises while answering' do
      coworker = Class.new do
        def ask(_prompt)
          raise 'boom'
        end
      end

      result = team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'check', 'coworker' => 'researcher' }
      )

      expect(result).to eq(error: "Coworker 'researcher' failed: boom")
    end

    it 'returns a recoverable error when a registered class cannot be instantiated' do
      coworker = Class.new do
        def initialize(name)
          @name = name
        end

        def ask(_prompt)
          'ok'
        end
      end

      result = team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'check', 'coworker' => 'researcher' }
      )

      expect(result[:error]).to include("Coworker 'researcher' failed:")
    end

    it 'returns message attachments with the reply content' do
      attachment = RubyLLM::Attachment.new(StringIO.new('image bytes'), filename: 'diagram.png')
      coworker = Class.new do
        define_method(:ask) do |_prompt|
          RubyLLM::Message.new(role: :assistant, content: 'See the diagram', attachments: [attachment])
        end
      end

      result = team_with(coworker).collaboration_tools.first.call(
        { 'task' => 'draw', 'coworker' => 'researcher' }
      )

      expect(result).to eq(['See the diagram', attachment])
    end

    it 'uses a stable snapshot of the registered coworkers' do
      tools = team.collaboration_tools
      team.add(:writer, coworker_class)

      result = tools.first.call({ 'task' => 'Draft', 'coworker' => 'writer' })

      expect(tools.first.description).to end_with('Coworkers: researcher')
      expect(result[:error]).to eq("Unknown coworker 'writer'. Available: researcher")
    end
  end

  describe 'live delegation', :live do
    it 'openrouter/nvidia/nemotron-3-super-120b-a12b:free delegates through collaboration tools' do
      skip_without_cassette_or_key('OPENROUTER_API_KEY')

      model_id = 'nvidia/nemotron-3-super-120b-a12b:free'
      provider = :openrouter
      coworker = Class.new(RubyLLM::Agent) do
        model model_id, provider: provider
        instructions 'You are a terse assistant. Answer in one short sentence.'
      end

      team = described_class.new.add(:researcher, coworker)
      chat = RubyLLM.chat(model: model_id, provider: provider)
                    .with_tools(*team.collaboration_tools)
                    .with_instructions(
                      'You must call the delegate_work tool with coworker "researcher" and ' \
                      'task "What is 2 + 2?" before answering. Then report what it says.'
                    )

      response = chat.ask('What is 2 plus 2? Ask your researcher teammate first.')

      delegation = chat.messages.flat_map { |message| message.tool_calls&.values || [] }.find do |tool_call|
        tool_call.name == 'delegate_work' && tool_call.arguments.values.any? { |value| value.to_s.include?('2 + 2') }
      end
      expect(delegation).not_to be_nil

      tool_result = chat.messages.find { |message| message.tool_call_id == delegation.id }
      expect(tool_result).not_to be_nil
      expect(tool_result.content).to include('4')
      expect(response.content).to include('4')
    end
  end
end
