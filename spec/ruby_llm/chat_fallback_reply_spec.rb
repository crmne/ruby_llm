# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:fallback_model) { model_for(:anthropic) }

  def answer(content = 'done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  before do
    allow(RubyLLM::Provider.resolve!(:anthropic)).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |provider| allow(provider).to receive(:complete).and_return(answer('stand-in')) }
    end
  end

  it 'names the fallback model and provider on the reply it wrote' do
    chat = described_class.new(model: model_for(:openai), provider: :openai).with_fallbacks(fallback_model)
    allow(chat.provider).to receive(:complete).and_raise(RubyLLM::RateLimitError.new('busy'))

    reply = chat.ask('Hi')

    expect(reply.content).to eq('stand-in')
    expect(reply.model).to eq(fallback_model)
    expect(reply.provider).to eq('anthropic')
  end

  it 'names the provider of a reply the chat model wrote' do
    chat = described_class.new(model: model_for(:openai), provider: :openai).with_fallbacks(fallback_model)
    allow(chat.provider).to receive(:complete).and_return(answer)

    reply = chat.ask('Hi')

    expect(reply.provider).to eq('openai')
    expect(RubyLLM::Message.new(reply.to_h).provider).to eq('openai')
    expect(RubyLLM::Message.new(reply.to_h)).not_to be_stood_in
  end

  context 'with a chat record' do
    let(:model_id) { model_for(:openai) }

    it 'prefers the provider of a successful attempt over the column' do
      chat = Chat.create!(model: model_id)
      reply = chat.messages.create!(role: 'assistant', content: 'done', provider: 'anthropic')
      chat.ruby_llm_usages.create!(operation: 'chat', provider: 'openai', model: model_id, status: 'succeeded',
                                   message: reply)

      expect(reply.reload.to_llm.provider).to eq('openai')
    end

    it 'names the fallback on a reply with no successful attempt, and only on replies' do
      chat = Chat.create!(model: model_id)
      reply = chat.messages.create!(role: 'assistant', content: 'par', finish_reason: 'cancelled',
                                    model_id: fallback_model, provider: 'anthropic')
      question = chat.messages.create!(role: 'user', content: 'Hi', model_id: fallback_model, provider: 'anthropic')

      expect(reply.to_llm.model).to eq(fallback_model)
      expect(reply.to_llm.provider).to eq('anthropic')
      expect(question.to_llm.model).to be_nil
      expect(question.to_llm.provider).to be_nil
    end

    it 'saves the model and provider of a fallback reply, and only of those' do
      chat = Chat.create!(model: model_id).with_fallbacks(fallback_model)
      provider = chat.to_llm.provider
      allow(provider).to receive(:complete).and_return(answer('mine'))
      chat.ask('First')
      allow(provider).to receive(:complete).and_raise(RubyLLM::RateLimitError.new('busy'))
      chat.ask('Second')

      own, stand_in = chat.messages.reload.where(role: 'assistant').order(:id).to_a

      expect(own.read_attribute(:model_id)).to be_nil
      expect(own.read_attribute(:provider)).to be_nil
      expect(stand_in.read_attribute(:model_id)).to eq(fallback_model)
      expect(stand_in.read_attribute(:provider)).to eq('anthropic')
      expect(stand_in.provider).to eq('anthropic')
      expect(own.provider).to eq('openai')
    end
  end
end
