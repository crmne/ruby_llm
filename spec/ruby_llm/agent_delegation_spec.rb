# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'delegates Chat state and cache boundaries to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai, :temperature))
                  .with_provider_tools(:web_search)
                  .with_tool_options(concurrency: :fibers)
                  .with_end_user('customer-42')
                  .with_owner(:alice)
                  .with_fallbacks(model_for(:openai, :alternate_chat))
    chat.add_message(role: :user, content: 'Hello')
    agent = Class.new(described_class).new(chat:)
    allow(RubyLLM.deprecator).to receive(:deprecate)

    expect(agent.provider).to be(chat.provider)
    expect(agent.provider_tools).to eq(chat.provider_tools)
    expect(agent.concurrency).to eq(:fibers)
    expect(agent.end_user).to eq('customer-42')
    expect(agent.owner).to eq(:alice)
    expect(agent.with_owner(:bob)).to be(chat)
    expect(agent.fallbacks).to eq(chat.fallbacks)
    expect(agent.cache_until_here).to be(chat)
    expect(agent).not_to be_waiting
    expect(RubyLLM.deprecator).to have_received(:deprecate)
      .with('RubyLLM::Chat#cache_until_here', replacement: /Message#cache_until_here/, removal: '3.0')
  end

  it 'delegates deprecated enumeration to the chat, which warns' do
    chat = RubyLLM.chat(model: model_for(:openai, :temperature))
    chat.add_message(role: :user, content: 'Hello')
    agent = Class.new(described_class).new(chat:)
    allow(RubyLLM.deprecator).to receive(:deprecate)

    expect(agent.map(&:content)).to eq(['Hello'])
    expect(agent.messages.map(&:content)).to eq(['Hello'])
    expect(RubyLLM.deprecator).to have_received(:deprecate)
      .with('Enumerable on RubyLLM::Chat', replacement: 'RubyLLM::Chat#messages', removal: '3.0').once
  end

  it 'delegates model_id to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai, :temperature))

    expect(chat.model_id).to eq(chat.model.id)
    expect(Class.new(described_class).new(chat:).model_id).to eq(chat.model.id)
  end

  it 'delegates around_join to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai))
    agent = Class.new(described_class).new(chat:)
    allow(chat).to receive(:around_join).and_return(chat)

    expect(agent.around_join { nil }).to be(chat)
  end

  it 'delegates withdraw to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai))
    queued = chat.queue('Hello')

    expect(Class.new(described_class).new(chat:).withdraw(queued)).to be(true)
    expect(chat.queued_messages).to be_empty
  end

  it 'delegates join_queued_messages to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai))
    chat.queue('Hello')

    expect(Class.new(described_class).new(chat:).join_queued_messages.map(&:content)).to eq(['Hello'])
  end

  it 'applies around_join callbacks declared on the class, inherited by subclasses' do
    events = []
    parent = Class.new(described_class) do
      around_join do |queued, join|
        events << [:parent, queued.content]
        join.call
      end
    end
    child = Class.new(parent) do
      around_join do |_queued, join|
        events << :child
        join.call
      end
    end
    chat = RubyLLM.chat(model: model_for(:openai))
    agent = child.new(chat:)
    child.new(chat:)
    chat.queue('Hello')

    agent.join_queued_messages

    expect(events).to eq([[:parent, 'Hello'], :child])
    expect(parent.around_join_callbacks.size).to eq(1)
    expect { parent.around_join }.to raise_error(ArgumentError)
  end

  it 'classifies every method defined on Chat' do
    expected_missing_methods = %i[
      approval_pending? continue_turn fallback_errors
      message_queue= messages= prepare_message raise_if_pending_tool_calls!
      raise_if_prompt_attachments! run= run_around_join take_queued_messages tool_call_state= tool_prefs
      add_usage_entry usage_entries usage_entries= agent_class agent_class= running_agent
    ]

    missing_methods = RubyLLM::Chat.public_instance_methods(false) - described_class.public_instance_methods(false)

    expect(missing_methods).to match_array(expected_missing_methods)
  end
end
