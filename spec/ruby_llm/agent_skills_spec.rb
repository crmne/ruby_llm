# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  let(:fixtures) { File.expand_path('../fixtures/skills', __dir__) }

  before { RubyLLM::Skill.roots << fixtures }
  after { RubyLLM::Skill.instance_variable_set(:@roots, nil) }

  def agent_with(&)
    Class.new(described_class) do
      model model_for(:openai), provider: :openai
      class_exec(&)
    end
  end

  it 'gives the chats it builds the skills it names' do
    agent = agent_with { skills :ticket_codes, File.expand_path('../fixtures/skills/csv-report', __dir__) }

    expect(agent.skills).to eq([:ticket_codes, File.join(fixtures, 'csv-report')])
    expect(agent.chat.skills.map(&:name)).to eq(%w[ticket-codes csv-report])
    expect(agent.chat.tools).to have_key(:load_skill)
  end

  it 'accepts the skill loader as the tool choice' do
    chat = agent_with do
      skills :ticket_codes
      tool_options choice: :load_skill
    end.chat

    expect(chat.tool_options[:choice]).to eq(:load_skill)
  end

  it 'gives every skill with true' do
    agent = agent_with { skills true }

    expect(agent.skills).to be(true)
    expect(agent.chat.skills.map(&:name)).to eq(%w[csv-report ticket-codes])
  end

  it 'has no skills without a declaration, even when skills exist' do
    agent = agent_with { temperature 0.1 }

    expect(agent.skills).to be_nil
    expect(agent.chat.skills).to eq([])
  end

  it "removes a parent's skills with false, and subclasses inherit them otherwise" do
    parent = agent_with { skills :ticket_codes }

    expect(Class.new(parent) { skills false }.chat.skills).to eq([])
    expect(Class.new(parent).chat.skills.map(&:name)).to eq(['ticket-codes'])
  end

  it 'rejects nil and true or false with names when declared' do
    expect { agent_with { skills nil } }.to raise_error(ArgumentError, /cannot be nil/)
    expect { agent_with { skills true, :ticket_codes } }.to raise_error(ArgumentError, /take no skill names/)
  end

  it 'raises when the chat is built with a missing skill' do
    agent = agent_with { skills :missing }

    expect { agent.chat }.to raise_error(RubyLLM::SkillNotFoundError)
  end

  it 'delegates with_skills and skills to the chat' do
    agent = agent_with { temperature 0.1 }.new

    expect(agent.with_skills(:csv_report)).to be(agent.chat)
    expect(agent.skills.map(&:name)).to eq(['csv-report'])
  end
end
