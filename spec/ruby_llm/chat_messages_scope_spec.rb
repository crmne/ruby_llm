# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_messages' do
    it 'uses all messages by default when no scope is configured' do
      chat = RubyLLM.chat
      provider = chat.instance_variable_get(:@provider)

      allow(provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: 'Test response')
      )

      chat.add_message(role: :user, content: 'one')
      chat.add_message(role: :assistant, content: 'two')

      chat.complete

      expect(provider).to have_received(:complete).with(
        chat.messages,
        hash_including(
          tools: chat.tools,
          temperature: anything,
          model: chat.model,
          params: chat.params,
          headers: chat.headers,
          schema: chat.schema
        )
      )
    end

    it 'applies a callable scope to the messages passed to the provider' do
      chat = RubyLLM.chat
      provider = chat.instance_variable_get(:@provider)

      allow(provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: 'Scoped response')
      )

      first = chat.add_message(role: :user, content: 'first')
      second = chat.add_message(role: :assistant, content: 'second')

      chat.with_messages { |msgs| [msgs.last] }

      chat.complete

      expect(provider).to have_received(:complete) do |messages_arg, **_options|
        expect(messages_arg).to eq([second])
        expect(messages_arg).not_to include(first)
      end
    end

    it 'can clear the scope by calling without a block' do
      chat = RubyLLM.chat
      provider = chat.instance_variable_get(:@provider)

      allow(provider).to receive(:complete).and_return(
        RubyLLM::Message.new(role: :assistant, content: 'Cleared scope response')
      )

      chat.add_message(role: :user, content: 'one')
      chat.add_message(role: :assistant, content: 'two')

      chat.with_messages { |msgs| [msgs.last] }
      chat.with_messages

      chat.complete

      expect(provider).to have_received(:complete).with(
        chat.messages,
        hash_including(
          tools: chat.tools,
          temperature: anything,
          model: chat.model,
          params: chat.params,
          headers: chat.headers,
          schema: chat.schema
        )
      )
    end

  end
end


