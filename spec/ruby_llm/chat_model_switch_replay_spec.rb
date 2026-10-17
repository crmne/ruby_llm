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

  context 'with an OpenAI Responses answer' do
    def answered_by(provider)
      entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model: 'gpt-5.4',
                                                    status: :succeeded)
      RubyLLM::Message.new(role: :assistant, content: 'Done.', phase: 'final_answer', usage_entries: [entry])
    end

    def answer_item(provider, model, message)
      chat = RubyLLM.chat(model:, provider:)
      chat.add_message(role: :user, content: 'Hi')
      chat.add_message(message)
      chat.add_message(role: :user, content: 'And now?')
      chat.render[:input][1]
    end

    it 'sends the phase back to the model that produced it' do
      expect(answer_item(:openai, 'gpt-5.4', answered_by('openai'))).to include(phase: 'final_answer')
    end

    it 'drops the phase for another provider' do
      expect(answer_item(:xai, model_for(:xai), answered_by('openai'))).not_to have_key(:phase)
    end
  end
end
