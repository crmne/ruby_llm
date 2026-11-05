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

  def chat_with_history(model, provider, protocol: nil)
    RubyLLM.chat(model:, provider:, protocol:).tap do |chat|
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

    it 'binds the first request, before any thinking is in the history' do
      chat = RubyLLM.chat(model: 'claude-opus-5-5', provider: :anthropic)
      chat.add_message(role: :user, content: 'First')

      expect(chat.render[:thinking]).to eq(type: 'adaptive', block_binding: drop)
    end

    it 'keeps thinking the same once thinking enters the history' do
      chat = RubyLLM.chat(model: 'claude-sonnet-5-5', provider: :anthropic)
      chat.add_message(role: :user, content: 'First')
      first = chat.render[:thinking]
      chat.add_message(thought('claude-sonnet-5-5'))
      chat.add_message(role: :user, content: 'Second')

      expect(chat.render[:thinking]).to eq(first)
    end

    it 'keeps an explicit effort beside the binding' do
      payload = RubyLLM.chat(model: 'claude-opus-5-5', provider: :anthropic).with_thinking(effort: :high)
                       .tap { |chat| chat.add_message(role: :user, content: 'First') }.render

      expect(payload[:thinking]).to eq(type: 'adaptive', block_binding: drop)
      expect(payload[:output_config]).to eq(effort: 'high')
    end

    it 'keeps thinking off on Claude Sonnet 5.5' do
      chat = chat_with_history('claude-sonnet-5-5', :anthropic).with_thinking(false)

      expect(chat.render[:thinking]).to eq(type: 'between_tools')
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

      RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).ask('Hello')

      expect(request).to have_been_requested
    end

    it 'sends the same beta before and after thinking enters the history' do
      reply = { content: [{ type: 'thinking', thinking: 'Hm', signature: 'signed' }, { type: 'text', text: 'Hi' }],
                usage: {} }
      request = stub_request(:post, 'https://api.anthropic.com/v1/messages')
                .with(headers: { 'anthropic-beta' => described_class::BETA })
                .to_return_json(body: reply)

      chat = RubyLLM.chat(model: 'claude-opus-5-5', provider: :anthropic)
      chat.ask('Hello')
      chat.ask('Again')

      expect(request).to have_been_requested.twice
    end
  end

  describe 'on Bedrock InvokeModel' do
    let(:replayed_blocks) { { 'anthropic' => [{ 'type' => 'thinking', 'thinking' => 'Hm', 'signature' => 'signed' }] } }

    it 'sends the binding and its beta in the body' do
      body = nil
      request = stub_request(:post, %r{/model/eu\.anthropic\.claude-opus-5-5/invoke\z})
                .with { |sent| body = JSON.parse(sent.body) }
                .to_return_json(body: { content: [{ type: 'text', text: 'Hi' }], usage: {} })

      chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock).complete

      expect(request).to have_been_requested
      expect(body['thinking']).to eq('type' => 'adaptive', 'block_binding' => drop.transform_keys(&:to_s))
      expect(body['anthropic_beta']).to eq([described_class::BETA])
    end

    it 'sends the binding and its beta on the first request' do
      body = nil
      stub_request(:post, %r{/model/eu\.anthropic\.claude-haiku-5-5/invoke\z})
        .with { |sent| body = JSON.parse(sent.body) }
        .to_return_json(body: { content: [{ type: 'text', text: 'Hi' }], usage: {} })

      RubyLLM.chat(model: 'eu.anthropic.claude-haiku-5-5', provider: :bedrock).ask('Hello')

      expect(body['thinking']).to eq('type' => 'adaptive', 'block_binding' => drop.transform_keys(&:to_s))
      expect(body['anthropic_beta']).to eq([described_class::BETA])
    end
  end

  describe 'on Bedrock Converse' do
    let(:replayed_blocks) do
      { 'converse' => [{ 'reasoningContent' => { 'reasoningText' => { 'text' => 'Hm', 'signature' => 'signed' } } }] }
    end

    it 'sends the binding and its beta in the additional fields' do
      fields = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock,
                                 protocol: :converse).render[:additionalModelRequestFields]

      expect(fields).to eq(thinking: { type: 'adaptive', block_binding: drop }, anthropic_beta: [described_class::BETA])
    end

    it 'binds the first request, before any thinking is in the history' do
      chat = RubyLLM.chat(model: 'eu.anthropic.claude-sonnet-5-5', provider: :bedrock, protocol: :converse)
      chat.add_message(role: :user, content: 'First')

      expect(chat.render[:additionalModelRequestFields])
        .to eq(thinking: { type: 'adaptive', block_binding: drop }, anthropic_beta: [described_class::BETA])
    end

    it 'keeps its beta beside betas from provider options' do
      chat = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock, protocol: :converse)
             .with_provider_options(additionalModelRequestFields: { anthropic_beta: ['other-beta'] })

      expect(chat.render[:additionalModelRequestFields][:anthropic_beta]).to eq(['other-beta', described_class::BETA])
    end

    it 'keeps thinking off when the chat turned it off' do
      off = { reasoning_config: { type: 'disabled' } }
      chat = chat_with_history('eu.anthropic.claude-opus-5-5', :bedrock, protocol: :converse)

      expect(RubyLLM::Protocols::Converse::Chat.send(:bind_thinking, off, chat.model)).to eq(off)
    end

    it 'leaves models that do not bind alone' do
      expect(chat_with_history('eu.anthropic.claude-haiku-4-5-20251001-v1:0', :bedrock, protocol: :converse).render)
        .not_to have_key(:additionalModelRequestFields)
    end
  end
end
