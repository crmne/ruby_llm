# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::NativeContent do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM.models.find(model_for(:gemini), provider: :gemini) }
  let(:protocol) { RubyLLM::Protocols::Gemini.new(RubyLLM::Providers::Gemini.new(RubyLLM.config), model) }

  def answer(provider:, model_id:, **native)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model: model_id, status: :succeeded)
    RubyLLM::Message.new(role: :assistant, content: 'Done.', usage_entries: [entry], **native)
  end

  it 'leaves an answer without native content as it is' do
    message = answer(provider: 'openai', model_id: model_for(:openai))

    expect(protocol.preprocess_message(message)).to equal(message)
  end

  it 'drops the raw content another model of the provider produced' do
    message = answer(provider: 'gemini', model_id: model_for(:gemini, :structured_output),
                     raw_content: [{ 'text' => 'Done.' }])

    expect(protocol.preprocess_message(message).raw_content).to be_nil
  end

  it 'treats a model the provider does not list as another model' do
    message = answer(provider: 'gemini', model_id: model_for(:openai), continuation: 'next')

    expect(protocol.preprocess_message(message).continuation).to be_nil
  end

  it 'keeps native content for the model that produced it' do
    message = answer(provider: 'gemini', model_id: model.id, continuation: 'next')

    expect(protocol.preprocess_message(message).continuation).to eq('next')
  end
end
