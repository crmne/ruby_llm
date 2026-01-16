# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Content do
  describe '.new' do
    it 'builds a raw text block' do
      raw = described_class.new('Hello world')

      expect(raw).to be_a(RubyLLM::Content::Raw)
      expect(raw.value).to eq([{ type: 'text', text: 'Hello world' }])
    end

    it 'adds ephemeral cache control when cache is true' do
      raw = described_class.new('Cached', cache: true)

      expect(raw.value.first[:cache_control]).to eq(type: 'ephemeral')
    end

    it 'uses explicit cache_control when provided' do
      raw = described_class.new('Custom', cache_control: { type: 'ephemeral', ttl: '1h' })

      expect(raw.value.first[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
    end

    it 'accepts custom parts without modification' do
      parts = [{ type: 'text', text: 'Prebuilt', cache_control: { type: 'ephemeral' } }]
      raw = described_class.new(parts: parts)

      expect(raw.value).to eq(parts)
    end
  end

  describe 'chat integration' do
    include_context 'with configured RubyLLM'

    it 'passes raw content through to the Anthropic provider' do
      chat = RubyLLM.chat(model: 'claude-sonnet-4-5', provider: :anthropic, assume_model_exists: true)
      provider = chat.instance_variable_get(:@provider)
      raw = described_class.new('Weather?', cache: true)

      allow(provider).to receive(:complete) do |messages, **_options, &|
        user_message = messages.find { |msg| msg.role == :user }
        expect(user_message.content).to be_a(RubyLLM::Content::Raw)
        expect(user_message.content.value.first[:cache_control]).to eq(type: 'ephemeral')

        RubyLLM::Message.new(role: :assistant, content: 'Fine')
      end

      chat.ask(raw)

      expect(provider).to have_received(:complete)
    end
  end
end
