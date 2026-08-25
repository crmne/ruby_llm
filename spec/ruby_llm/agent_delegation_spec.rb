# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Agent do
  include_context 'with configured RubyLLM'

  it 'delegates Chat state and cache boundaries to the underlying chat' do
    chat = RubyLLM.chat(model: 'gpt-4.1-nano')
                  .with_server_tools(:web_search)
                  .with_tool_options(concurrency: :fibers)
                  .with_end_user('customer-42')
                  .with_fallbacks('gpt-4.1-mini')
    chat.add_message(role: :user, content: 'Hello')
    agent = Class.new(described_class).new(chat:)

    expect(agent.provider).to be(chat.provider)
    expect(agent.server_tools).to eq(chat.server_tools)
    expect(agent.concurrency).to eq(:fibers)
    expect(agent.end_user).to eq('customer-42')
    expect(agent.fallbacks).to eq(chat.fallbacks)
    expect(agent.cache_until_here!).to be(chat)
  end

  it 'classifies every method defined on Chat' do
    expected_missing_methods = %i[
      approval_checker= cancellation_checker= fallback_errors messages=
      raise_if_pending_tool_calls! tool_prefs usage_entries usage_entries= usage_recorder=
    ]

    missing_methods = RubyLLM::Chat.public_instance_methods(false) - described_class.public_instance_methods(false)

    expect(missing_methods).to match_array(expected_missing_methods)
  end
end
