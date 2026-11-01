# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::BlockBinding do
  include_context 'with configured RubyLLM'

  let(:drop) { { prefix_mismatch_behavior: 'drop_block' } }

  def thought(model)
    RubyLLM::Message.new(role: :assistant, content: 'Done', model:,
                         raw_reasoning: replayed_blocks,
                         thinking: RubyLLM::Thinking.build(text: 'Hm', signature: 'signed'))
  end

  def chat_with_history(model, provider)
    RubyLLM.chat(model:, provider:).tap do |chat|
      chat.add_message(role: :user, content: 'First')
      chat.add_message(thought(model))
      chat.add_message(role: :user, content: 'Second')
    end
  end

  describe 'on the Anthropic API' do
    let(:replayed_blocks) { { 'anthropic' => [{ 'type' => 'thinking', 'thinking' => 'Hm', 'signature' => 'signed' }] } }

    it 'drops stale blocks when a binding model replays thinking' do
      expect(chat_with_history('claude-opus-5-5', :anthropic).render[:thinking])
        .to eq(type: 'adaptive', block_binding: drop)
    end

    it 'leaves a request without replayed thinking alone' do
      chat = RubyLLM.chat(model: 'claude-opus-5-5', provider: :anthropic)
      chat.add_message(role: :user, content: 'First')

      expect(chat.render).not_to have_key(:thinking)
    end

    it 'leaves models that do not bind alone' do
      expect(chat_with_history('claude-haiku-4-5', :anthropic).render).not_to have_key(:thinking)
    end

    it 'keeps thinking off when the chat turned it off' do
      expect(described_class.apply({ type: 'disabled' })).to be_nil
    end

    it 'sends no beta without the binding' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages')
                .with { |sent| !sent.headers.key?('Anthropic-Beta') }
                .to_return_json(body: { content: [{ type: 'text', text: 'Hi' }], usage: {} })

      RubyLLM.chat(model: 'claude-opus-5-5', provider: :anthropic).ask('Hello')

      expect(request).to have_been_requested
    end

    it 'sends the beta with the binding' do
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages')
                .with(headers: { 'anthropic-beta' => described_class::BETA })
                .to_return_json(body: { content: [{ type: 'text', text: 'Hi' }], usage: {} })

      chat_with_history('claude-opus-5-5', :anthropic).complete

      expect(request).to have_been_requested
    end
  end

  describe 'on Bedrock Converse' do
    let(:replayed_blocks) do
      { 'converse' => [{ 'reasoningContent' => { 'reasoningText' => { 'text' => 'Hm', 'signature' => 'signed' } } }] }
    end

    it 'sends the binding and its beta in the additional fields' do
      fields = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock).render[:additionalModelRequestFields]

      expect(fields).to eq(thinking: { type: 'adaptive', block_binding: drop }, anthropic_beta: [described_class::BETA])
    end

    it 'keeps its beta beside betas from provider options' do
      chat = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock)
             .with_provider_options(additionalModelRequestFields: { anthropic_beta: ['other-beta'] })

      expect(chat.render[:additionalModelRequestFields][:anthropic_beta]).to eq(['other-beta', described_class::BETA])
    end

    it 'keeps thinking off when the chat turned it off' do
      off = { reasoning_config: { type: 'disabled' } }
      chat = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock)
      messages = [{ content: [{ reasoningContent: {} }] }]

      expect(RubyLLM::Protocols::Converse::Chat.send(:bind_replayed_thinking, off, messages, chat.model)).to eq(off)
    end

    it 'leaves models that do not bind alone' do
      expect(chat_with_history('eu.anthropic.claude-haiku-4-5-20251001-v1:0', :bedrock).render)
        .not_to have_key(:additionalModelRequestFields)
    end
  end
end
