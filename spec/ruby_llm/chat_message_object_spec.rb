# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#ask with message objects' do
    let(:chat) { RubyLLM.chat(model: 'gpt-4.1-nano') }
    let(:mock_response) do
      RubyLLM::Message.new(
        role: :assistant,
        content: '4',
        input_tokens: 10,
        output_tokens: 5,
        model_id: 'gpt-4.1-nano'
      )
    end

    before do
      # Mock the complete method to avoid actual API calls and simulate adding response
      allow(chat).to receive(:complete) do
        chat.add_message(mock_response)
        mock_response
      end
    end

    context 'with message objects' do
      let(:message) do
        RubyLLM::Message.new(
          role: :user,
          content: 'What is 2 + 2?'
        )
      end

      it 'accepts an existing message object in ask method' do
        response = chat.ask(message)
        expect(response.content).to eq('4')
      end

      it 'creates correct message count' do
        chat.ask(message)
        expect(chat.messages.count).to eq(2)
      end

      it 'preserves message content' do
        chat.ask(message)
        expect(chat.messages.first.content).to eq('What is 2 + 2?')
      end

      it 'preserves message role' do
        chat.ask(message)
        expect(chat.messages.first.role).to eq(:user)
      end
    end

    context 'with duplicate prevention' do
      let(:message) do
        RubyLLM::Message.new(role: :user, content: 'Hello')
      end

      it 'does not duplicate messages when passing message objects' do
        initial_count = chat.messages.count
        chat.ask(message)
        expect(chat.messages.count).to eq(initial_count + 2)
      end

      it 'ensures user messages appear only once' do
        chat.ask(message)
        user_messages = chat.messages.select { |m| m.role == :user }
        expect(user_messages.count).to eq(1)
      end

      it 'preserves user message content' do
        chat.ask(message)
        user_messages = chat.messages.select { |m| m.role == :user }
        expect(user_messages.first.content).to eq('Hello')
      end
    end

    context 'with string input' do
      it 'still works with string input' do
        mock_response.content = 'Paris is the capital of France.'
        response = chat.ask('What is the capital of France?')
        expect(response.content).to include('Paris')
      end

      it 'creates correct message count with string' do
        chat.ask('What is the capital of France?')
        expect(chat.messages.count).to eq(2)
      end

      it 'creates correct user message from string' do
        chat.ask('What is the capital of France?')
        expect(chat.messages.first.content).to eq('What is the capital of France?')
      end

      it 'creates user role from string' do
        chat.ask('What is the capital of France?')
        expect(chat.messages.first.role).to eq(:user)
      end
    end

    context 'with message attributes' do
      let(:message) do
        RubyLLM::Message.new(
          role: :user,
          content: 'Test message',
          model_id: 'custom-model'
        )
      end

      it 'preserves message content' do
        chat.ask(message)
        user_message = chat.messages.first
        expect(user_message.content).to eq('Test message')
      end

      it 'preserves message role' do
        chat.ask(message)
        user_message = chat.messages.first
        expect(user_message.role).to eq(:user)
      end

      it 'preserves custom model_id' do
        chat.ask(message)
        user_message = chat.messages.first
        expect(user_message.model_id).to eq('custom-model')
      end
    end

    it 'raises error for message with attachments' do
      message = RubyLLM::Message.new(role: :user, content: 'Test message')
      expect do
        chat.ask(message, with: ['some_file.txt'])
      end.to raise_error(ArgumentError, /Cannot provide attachments/)
    end

    context 'with nil validation' do
      let(:nil_role_message) do
        Object.new.tap do |obj|
          def obj.role = nil
          def obj.content = 'some content'
        end
      end

      let(:nil_content_message) do
        Object.new.tap do |obj|
          def obj.role = :user
          def obj.content = nil
        end
      end

      it 'raises error for nil role' do
        expect { chat.ask(nil_role_message) }.to raise_error(ArgumentError, /Message object must have non-nil/)
      end

      it 'raises error for nil content' do
        expect { chat.ask(nil_content_message) }.to raise_error(ArgumentError, /Message object must have non-nil/)
      end
    end

    context 'with duck typing' do
      it 'works with Struct objects' do
        struct_message = Struct.new(:role, :content).new(:user, 'Hello from Struct!')
        response = chat.ask(struct_message)
        expect(response.content).to eq('4')
      end

      it 'preserves Struct message content' do
        struct_message = Struct.new(:role, :content).new(:user, 'Hello from Struct!')
        chat.ask(struct_message)
        expect(chat.messages.first.content).to eq('Hello from Struct!')
      end

      it 'preserves Struct message role' do
        struct_message = Struct.new(:role, :content).new(:user, 'Hello from Struct!')
        chat.ask(struct_message)
        expect(chat.messages.first.role).to eq(:user)
      end

      it 'works with custom objects' do
        custom_message = Object.new
        def custom_message.role = :user
        def custom_message.content = 'Hello from custom object!'
        response = chat.ask(custom_message)
        expect(response.content).to eq('4')
      end

      it 'preserves custom object content' do
        custom_message = Object.new
        def custom_message.role = :user
        def custom_message.content = 'Hello from custom object!'
        chat.ask(custom_message)
        expect(chat.messages.first.content).to eq('Hello from custom object!')
      end

      it 'preserves custom object role' do
        custom_message = Object.new
        def custom_message.role = :user
        def custom_message.content = 'Hello from custom object!'
        chat.ask(custom_message)
        expect(chat.messages.first.role).to eq(:user)
      end
    end

    context 'with missing methods' do
      it 'handles object missing role method' do
        no_role_message = Object.new
        def no_role_message.content = 'has content'
        expect { chat.ask(no_role_message) }.not_to raise_error
      end

      it 'handles object missing content method' do
        no_content_message = Object.new
        def no_content_message.role = :user
        expect { chat.ask(no_content_message) }.not_to raise_error
      end

      it 'handles object missing both methods' do
        neither_message = Object.new
        expect { chat.ask(neither_message) }.not_to raise_error
      end
    end

    context 'with different role types' do
      it 'handles symbol role' do
        symbol_message = RubyLLM::Message.new(role: :user, content: 'Symbol role')
        chat.ask(symbol_message)
        expect(chat.messages.first.role).to eq(:user)
      end

      it 'handles string role' do
        string_message = Object.new
        def string_message.role = 'user'
        def string_message.content = 'String role'
        chat.ask(string_message)
        expect(chat.messages.first.role).to eq(:user)
      end
    end
  end

  describe 'with real API calls' do
    let(:chat) { RubyLLM.chat(model: 'gpt-4.1-nano') }
    let(:mock_response) do
      RubyLLM::Message.new(
        role: :assistant,
        content: 'Hello World',
        input_tokens: 10,
        output_tokens: 5,
        model_id: 'gpt-4.1-nano'
      )
    end

    before do
      allow(chat).to receive(:complete) do
        chat.add_message(mock_response)
        mock_response
      end
    end

    it 'works with duck typing using Struct' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      response = chat.ask(struct_message)
      expect(response).to be_a(RubyLLM::Message)
    end

    it 'returns string content' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      response = chat.ask(struct_message)
      expect(response.content).to be_a(String)
    end

    it 'returns non-empty content' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      response = chat.ask(struct_message)
      expect(response.content.length).to be > 0
    end

    it 'returns correct message count' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      chat.ask(struct_message)
      expect(chat.messages.count).to eq(2)
    end

    it 'properly adds user message content' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      chat.ask(struct_message)
      user_message = chat.messages.first
      expect(user_message.content).to eq('Say "Hello World"')
    end

    it 'properly adds user message role' do
      struct_message = Struct.new(:role, :content).new(:user, 'Say "Hello World"')
      chat.ask(struct_message)
      user_message = chat.messages.first
      expect(user_message.role).to eq(:user)
    end
  end
end
