# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_fallback' do
    let(:chat) { described_class.new(model: 'gpt-4.1-nano') }

    it 'returns self for chaining' do
      expect(chat.with_fallback('claude-haiku-4-5-20251001')).to eq(chat)
    end

    it 'tries fallback model on transient errors' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      call_count = 0
      allow(chat.instance_variable_get(:@provider)).to receive(:complete) do
        call_count += 1
        raise RubyLLM::ServiceUnavailableError.new(nil, 'model experiencing high demand')
      end

      fallback_provider = instance_double(RubyLLM::Provider)
      fallback_response = RubyLLM::Message.new(role: :assistant, content: 'Hello from fallback!')

      allow(RubyLLM::Models).to receive(:resolve).and_call_original
      allow(RubyLLM::Models).to receive(:resolve)
        .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
        .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])

      allow(fallback_provider).to receive(:connection).and_return(double)
      allow(fallback_provider).to receive(:complete).and_return(fallback_response)

      chat.add_message(role: :user, content: 'Hello')
      response = chat.complete

      expect(response.content).to eq('Hello from fallback!')
      expect(call_count).to eq(1)
    end

    it 'raises original error when fallback also fails' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      original_error = RubyLLM::ServiceUnavailableError.new(nil, 'primary down')
      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(original_error)

      fallback_provider = instance_double(RubyLLM::Provider)
      allow(RubyLLM::Models).to receive(:resolve).and_call_original
      allow(RubyLLM::Models).to receive(:resolve)
        .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
        .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])
      allow(fallback_provider).to receive(:connection).and_return(double)
      allow(fallback_provider).to receive(:complete)
        .and_raise(RubyLLM::ServerError.new(nil, 'fallback also down'))

      chat.add_message(role: :user, content: 'Hello')

      expect { chat.complete }.to raise_error(RubyLLM::ServiceUnavailableError, 'primary down')
    end

    it 'restores original model when fallback fails' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      original_model = chat.model
      original_provider = chat.instance_variable_get(:@provider)

      allow(original_provider).to receive(:complete)
        .and_raise(RubyLLM::OverloadedError.new(nil, 'overloaded'))

      fallback_provider = instance_double(RubyLLM::Provider)
      allow(RubyLLM::Models).to receive(:resolve).and_call_original
      allow(RubyLLM::Models).to receive(:resolve)
        .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
        .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])
      allow(fallback_provider).to receive(:connection).and_return(double)
      allow(fallback_provider).to receive(:complete)
        .and_raise(RubyLLM::ServerError.new(nil, 'fallback down'))

      chat.add_message(role: :user, content: 'Hello')

      expect { chat.complete }.to raise_error(RubyLLM::OverloadedError)
      expect(chat.model).to eq(original_model)
      expect(chat.instance_variable_get(:@provider)).to eq(original_provider)
    end

    it 'does not trigger fallback on non-transient errors' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(RubyLLM::BadRequestError.new(nil, 'invalid request'))

      chat.add_message(role: :user, content: 'Hello')

      expect { chat.complete }.to raise_error(RubyLLM::BadRequestError, 'invalid request')
    end

    it 'does not trigger fallback on auth errors' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(RubyLLM::UnauthorizedError.new(nil, 'bad key'))

      chat.add_message(role: :user, content: 'Hello')

      expect { chat.complete }.to raise_error(RubyLLM::UnauthorizedError)
    end

    it 'preserves message history across fallback' do
      chat.with_fallback('claude-haiku-4-5-20251001')
      chat.add_message(role: :user, content: 'First message')
      chat.add_message(role: :assistant, content: 'First reply')
      chat.add_message(role: :user, content: 'Second message')

      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(RubyLLM::RateLimitError.new(nil, 'rate limited'))

      captured_messages = nil
      fallback_provider = instance_double(RubyLLM::Provider)
      allow(RubyLLM::Models).to receive(:resolve).and_call_original
      allow(RubyLLM::Models).to receive(:resolve)
        .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
        .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])
      allow(fallback_provider).to receive(:connection).and_return(double)
      allow(fallback_provider).to receive(:complete) do |messages, **_kwargs|
        captured_messages = messages.dup
        RubyLLM::Message.new(role: :assistant, content: 'Fallback reply')
      end

      chat.complete

      expect(captured_messages.length).to eq(3)
      expect(captured_messages[0].content).to eq('First message')
      expect(captured_messages[1].content).to eq('First reply')
      expect(captured_messages[2].content).to eq('Second message')
    end

    it 'works with streaming' do
      chat.with_fallback('claude-haiku-4-5-20251001')

      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(RubyLLM::ServiceUnavailableError.new(nil, 'unavailable'))

      fallback_provider = instance_double(RubyLLM::Provider)
      allow(RubyLLM::Models).to receive(:resolve).and_call_original
      allow(RubyLLM::Models).to receive(:resolve)
        .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
        .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])
      allow(fallback_provider).to receive(:connection).and_return(double)
      allow(fallback_provider).to receive(:complete) do |_messages, **_kwargs, &block|
        block&.call(RubyLLM::Chunk.new(role: :assistant, content: 'chunk'))
        RubyLLM::Message.new(role: :assistant, content: 'streamed reply')
      end

      chat.add_message(role: :user, content: 'Hello')

      chunks = []
      response = chat.complete { |chunk| chunks << chunk }

      expect(response.content).to eq('streamed reply')
      expect(chunks).not_to be_empty
    end

    it 'does not fallback when no fallback is configured' do
      allow(chat.instance_variable_get(:@provider)).to receive(:complete)
        .and_raise(RubyLLM::ServiceUnavailableError.new(nil, 'unavailable'))

      chat.add_message(role: :user, content: 'Hello')

      expect { chat.complete }.to raise_error(RubyLLM::ServiceUnavailableError)
    end

    [
      RubyLLM::RateLimitError,
      RubyLLM::ServerError,
      RubyLLM::ServiceUnavailableError,
      RubyLLM::OverloadedError
    ].each do |error_class|
      it "triggers fallback on #{error_class.name.split('::').last}" do
        chat.with_fallback('claude-haiku-4-5-20251001')

        allow(chat.instance_variable_get(:@provider)).to receive(:complete)
          .and_raise(error_class.new(nil, 'error'))

        fallback_provider = instance_double(RubyLLM::Provider)
        allow(RubyLLM::Models).to receive(:resolve).and_call_original
        allow(RubyLLM::Models).to receive(:resolve)
          .with('claude-haiku-4-5-20251001', provider: nil, assume_exists: false, config: anything)
          .and_return([RubyLLM::Models.find('claude-haiku-4-5-20251001'), fallback_provider])
        allow(fallback_provider).to receive(:connection).and_return(double)
        allow(fallback_provider).to receive(:complete)
          .and_return(RubyLLM::Message.new(role: :assistant, content: 'ok'))

        chat.add_message(role: :user, content: 'Hello')
        response = chat.complete

        expect(response.content).to eq('ok')
      end
    end
  end
end
