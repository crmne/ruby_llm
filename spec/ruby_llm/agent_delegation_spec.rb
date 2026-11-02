# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'delegates Chat state and cache boundaries to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai, :temperature))
                  .with_provider_tools(:web_search)
                  .with_tool_options(concurrency: :fibers)
                  .with_end_user('customer-42')
                  .with_fallbacks(model_for(:openai, :alternate_chat))
    chat.add_message(role: :user, content: 'Hello')
    agent = Class.new(described_class).new(chat:)

    expect(agent.provider).to be(chat.provider)
    expect(agent.provider_tools).to eq(chat.provider_tools)
    expect(agent.concurrency).to eq(:fibers)
    expect(agent.end_user).to eq('customer-42')
    expect(agent.fallbacks).to eq(chat.fallbacks)
    expect(agent.cache_until_here).to be(chat)
    expect(agent).not_to be_waiting
  end

  it 'delegates model_id to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai, :temperature))

    expect(chat.model_id).to eq(chat.model.id)
    expect(Class.new(described_class).new(chat:).model_id).to eq(chat.model.id)
  end

  it 'delegates the queue callbacks to the underlying chat' do
    chat = RubyLLM.chat(model: model_for(:openai))
    agent = Class.new(described_class).new(chat:)

    %i[after_queue after_join after_unqueue].each do |callback|
      allow(chat).to receive(callback).and_return(chat)

      expect(agent.public_send(callback) { nil }).to be(chat)
    end
  end

  it 'classifies every method defined on Chat' do
    expected_missing_methods = %i[
      approval_pending? cancellation_checker= continue_turn fallback_errors
      interruptions= message_queue= messages= prepare_message raise_if_pending_tool_calls!
      raise_if_prompt_attachments! take_queued_messages tool_call_state= tool_prefs
      add_usage_entry usage_entries usage_entries= usage_recorder= progress_recorder=
    ]

    missing_methods = RubyLLM::Chat.public_instance_methods(false) - described_class.public_instance_methods(false)

    expect(missing_methods).to match_array(expected_missing_methods)
  end
end
