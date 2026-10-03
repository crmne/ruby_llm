# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:nova) { model_for(:bedrock) }
  let(:claude) { model_for(:bedrock, :structured_output) }
  let(:reasoning) { [{ 'reasoningContent' => { 'reasoningText' => { 'text' => 'Checking.' } } }] }

  def produced_by(model)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider: 'bedrock', model:, status: :succeeded)
    RubyLLM::Message.new(role: :assistant, content: 'Done.', thinking: RubyLLM::Thinking.build(text: 'Checking.'),
                         raw_reasoning: { 'converse' => reasoning }, usage_entries: [entry])
  end

  def render(model, message)
    chat = RubyLLM.chat(model:, provider: :bedrock)
    chat.add_message(role: :user, content: 'Hi')
    chat.add_message(message)
    chat.add_message(role: :user, content: 'And now?')
    chat.render
  end

  it 'replays the reasoning of another model on the same provider without it' do
    payload = render(claude, produced_by(nova))

    expect(payload[:messages][1][:content]).to eq([{ text: 'Done.' }])
  end

  it 'replays reasoning to the model that produced it' do
    payload = render(nova, produced_by(nova))

    expect(JSON.parse(JSON.generate(payload[:messages][1][:content]))).to eq(reasoning + [{ 'text' => 'Done.' }])
  end
end
