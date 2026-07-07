# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#before_request' do
    let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: 'anthropic') }

    it 'lets hooks mutate the rendered payload in place' do
      chat.before_request { |payload| payload[:metadata] = { user_id: 'u-1' } }
      chat.ask_later('Hello')

      expect(chat.render[:metadata]).to eq({ user_id: 'u-1' })
    end

    it 'lets hooks add provider-native content blocks' do
      chat.before_request do |payload|
        payload[:messages].last[:content] << { type: 'custom_context', data: 'x' }
      end
      chat.ask_later('Hello')

      expect(chat.render[:messages].last[:content].last).to eq({ type: 'custom_context', data: 'x' })
    end

    it 'supports wholesale replacement via payload.replace' do
      chat.before_request { |payload| payload.replace(payload.merge(stream: true)) }
      chat.ask_later('Hello')

      expect(chat.render[:stream]).to be true
    end

    it 'ignores hook return values' do
      chat.before_request { |payload| { replacement: true } if payload }
      chat.ask_later('Hello')

      expect(chat.render).not_to have_key(:replacement)
      expect(chat.render[:messages]).to be_an(Array)
    end

    it 'runs hooks in registration order after params merging' do
      chat.with_provider_options(metadata: { user_id: 'from-params' })
      chat.before_request { |payload| payload[:metadata][:user_id] = 'from-hook' }
      chat.ask_later('Hello')

      expect(chat.render[:metadata]).to eq({ user_id: 'from-hook' })
    end
  end
end
