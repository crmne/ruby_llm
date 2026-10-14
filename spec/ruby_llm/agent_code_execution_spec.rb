# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  around do |example|
    original = RubyLLM.config.sandbox
    RubyLLM.config.sandbox = FakeSandbox.new
    example.run
  ensure
    RubyLLM.config.sandbox = original
  end

  def agent_with(&)
    Class.new(described_class) do
      model model_for(:openai), provider: :openai
      class_exec(&)
    end
  end

  it 'enables code execution for the chats it builds' do
    chat = agent_with { code_execution }.chat

    expect(chat.code_execution).to eq(languages: %i[ruby shell])
    expect(chat.tools).to have_key(:run_code)
  end

  it 'passes options as keywords or a Hash' do
    keywords = agent_with { code_execution languages: [:python], timeout: 5 }.chat
    hash = agent_with { code_execution({ 'gems' => %w[prawn] }) }.chat

    expect(keywords.code_execution).to eq(languages: [:python], timeout: 5)
    expect(hash.code_execution).to eq(gems: %w[prawn], languages: %i[ruby shell])
    expect(agent_with { code_execution virtualenv: '/opt/venv', readable: ['/opt/fonts'] }.chat.code_execution)
      .to eq(virtualenv: '/opt/venv', readable: ['/opt/fonts'], languages: %i[ruby python shell])
  end

  it 'disables code execution with false, also for subclasses' do
    parent = agent_with { code_execution }
    child = Class.new(parent) { code_execution false }

    expect(child.chat.code_execution).to be(false)
    expect(Class.new(parent).chat.code_execution).to eq(languages: %i[ruby shell])
  end

  it 'rejects nil and unknown options when declared' do
    expect { agent_with { code_execution nil } }.to raise_error(ArgumentError)
    expect { agent_with { code_execution memory: 1 } }.to raise_error(ArgumentError, /got memory/)
  end

  it 'raises ConfigurationError when the chat is built without a sandbox' do
    agent = agent_with { code_execution }
    RubyLLM.config.sandbox = nil

    expect { agent.chat }.to raise_error(RubyLLM::ConfigurationError)
  end

  it 'delegates with_code_execution and code_execution to the chat' do
    agent = agent_with { temperature 0.1 }.new

    expect(agent.with_code_execution(timeout: 9)).to be(agent.chat)
    expect(agent.code_execution).to eq(timeout: 9, languages: %i[ruby shell])
  end
end
