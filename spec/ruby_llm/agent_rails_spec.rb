# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  def write_prompt(agent_name, content)
    prompt_dir = Rails.root.join('app/prompts', agent_name)
    FileUtils.mkdir_p(prompt_dir)
    File.write(prompt_dir.join('instructions.txt.erb'), content)
    prompt_dir
  end

  it 'creates a Rails chat via .create! and renders prompt shorthand instructions' do
    prompt_dir = write_prompt(
      'spec_support_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      model 'gpt-4.1-nano'
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecSupportAgent', agent_class)

    chat = SpecSupportAgent.create!(display_name: 'Ava')

    expect(chat).to be_a(Chat)
    expect(chat.messages.where(role: 'system').count).to eq(1)
    expect(chat.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'loads instructions.txt.erb when instructions is called without arguments' do
    prompt_dir = write_prompt(
      'spec_default_prompt_agent',
      'Default prompt for chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      model 'gpt-4.1-nano'
      instructions
    end

    stub_const('SpecDefaultPromptAgent', agent_class)

    chat = SpecDefaultPromptAgent.create!
    expect(chat.messages.find_by(role: 'system').content).to eq("Default prompt for chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'exposes chat_model record as chat in execution context for .create! and .find' do
    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      model 'gpt-4.1-nano'
      instructions { "chat-class: #{chat.class.name}" }
    end

    stub_const('SpecChatContextAgent', agent_class)

    created = SpecChatContextAgent.create!
    expect(created.messages.find_by(role: 'system').content).to eq('chat-class: Chat')

    loaded = SpecChatContextAgent.find(created.id)
    runtime_chat = loaded.instance_variable_get(:@chat)
    expect(runtime_chat.messages.first.content).to eq('chat-class: Chat')
  end

  it 'finds a Rails chat and applies runtime instructions without persisting them' do
    prompt_dir = write_prompt(
      'spec_runtime_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      model 'gpt-4.1-nano'
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecRuntimeAgent', agent_class)

    chat = SpecRuntimeAgent.create!(display_name: 'Ava')
    persisted_system = chat.messages.find_by(role: 'system').content

    loaded = SpecRuntimeAgent.find(chat.id, display_name: 'Bea')
    runtime_chat = loaded.instance_variable_get(:@chat)

    expect(loaded.messages.where(role: 'system').count).to eq(1)
    expect(loaded.messages.find_by(role: 'system').content).to eq(persisted_system)
    expect(runtime_chat.messages.first.content).to eq("System for Bea on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'syncs instructions explicitly via .sync_instructions!' do
    prompt_dir = write_prompt(
      'spec_sync_agent',
      'System for <%= display_name %> on chat <%= chat.id %>'
    )

    agent_class = Class.new(RubyLLM::Agent) do
      chat_model Chat
      model 'gpt-4.1-nano'
      inputs :display_name
      instructions display_name: -> { display_name }
    end

    stub_const('SpecSyncAgent', agent_class)

    chat = SpecSyncAgent.create!(display_name: 'Ava')
    expect(chat.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")

    SpecSyncAgent.find(chat.id, display_name: 'Bea')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Ava on chat #{chat.id}")

    SpecSyncAgent.sync_instructions!(chat, display_name: 'Bea')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Bea on chat #{chat.id}")

    SpecSyncAgent.sync_instructions!(chat.id, display_name: 'Cia')
    expect(chat.reload.messages.find_by(role: 'system').content).to eq("System for Cia on chat #{chat.id}")
  ensure
    FileUtils.rm_rf(prompt_dir) if prompt_dir
  end

  it 'raises when .create! is used without chat_model' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    expect do
      agent_class.create!
    end.to raise_error(ArgumentError, /chat_model must be configured/)
  end

  it 'raises when .sync_instructions! is used without chat_model' do
    agent_class = Class.new(RubyLLM::Agent) do
      model 'gpt-4.1-nano'
    end

    expect do
      agent_class.sync_instructions!(1)
    end.to raise_error(ArgumentError, /chat_model must be configured/)
  end
end
