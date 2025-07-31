# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  include_context 'with configured RubyLLM'

  describe 'ChatMethods#ask with existing message' do
    let(:chat) { Chat.create!(model_id: 'gpt-4.1-nano') }
    let(:mock_response) do
      RubyLLM::Message.new(
        role: :assistant,
        content: '4',
        input_tokens: 10,
        output_tokens: 5,
        model_id: 'gpt-4.1-nano'
      )
    end
    let(:llm_chat) { instance_double(RubyLLM::Chat) }

    before do
      # Mock to avoid actual API calls but simulate message persistence
      allow(chat).to receive(:to_llm).and_return(llm_chat)
      allow(llm_chat).to receive(:add_message)
      allow(llm_chat).to receive(:complete) do
        # Create the assistant message in the database
        chat.messages.create!(
          role: 'assistant',
          content: mock_response.content,
          input_tokens: mock_response.input_tokens,
          output_tokens: mock_response.output_tokens,
          model_id: mock_response.model_id
        )
      end
    end

    context 'with existing message records' do
      let(:user_message) do
        chat.messages.create!(
          role: 'user',
          content: 'What is 2 + 2?'
        )
      end

      it 'accepts an existing message record in ask method' do
        # User message is already created and in the collection
        raise 'User message not in chat messages' unless chat.messages.include?(user_message)

        initial_count = chat.messages.count
        chat.ask(user_message)
        # Should only add the assistant response
        expect(chat.messages.count).to eq(initial_count + 1)
      end

      it 'returns an ActiveRecord model' do
        response = chat.ask(user_message)
        expect(response).to be_a(Message)
      end

      it 'preserves the original user message' do
        chat.ask(user_message)
        user_messages = chat.messages.where(role: 'user')
        expect(user_messages.count).to eq(1)
      end

      it 'preserves the original user message id' do
        chat.ask(user_message)
        user_messages = chat.messages.where(role: 'user')
        expect(user_messages.first.id).to eq(user_message.id)
      end
    end

    context 'with rich content attributes' do
      before do
        ActiveRecord::Migration.suppress_messages do
          unless Message.column_names.include?('rich_content')
            ActiveRecord::Migration.add_column :messages, :rich_content, :text
          end
        end
        Message.reset_column_information
      end

      let(:user_message) do
        msg = chat.messages.create!(role: 'user', content: 'Hello world')
        msg.update_column(:rich_content, '<p>Hello <strong>world</strong></p>')
        msg
      end

      it 'preserves additional attributes when passing message objects' do
        chat.ask(user_message)
        user_message.reload
        expect(user_message.content).to eq('Hello world')
      end

      it 'preserves rich_content attribute' do
        chat.ask(user_message)
        user_message.reload
        expect(user_message.read_attribute(:rich_content)).to eq('<p>Hello <strong>world</strong></p>')
      end
    end

    context 'with messages in collection' do
      let(:user_message) do
        chat.messages.create!(
          role: 'user',
          content: 'Test message'
        )
      end

      it 'includes user message in collection' do
        expect(chat.messages).to include(user_message)
      end

      it 'handles messages already in the collection' do
        # User message is already created and in the collection
        raise 'Expected chat.messages.include?(user_message)' unless chat.messages.include?(user_message)

        initial_count = chat.messages.count
        chat.ask(user_message)
        # Should only add the assistant response
        expect(chat.messages.count).to eq(initial_count + 1)
      end

      it 'does not duplicate user messages' do
        chat.ask(user_message)
        user_messages = chat.messages.where(role: 'user')
        expect(user_messages.count).to eq(1)
      end
    end

    context 'with string input' do
      it 'still works with string input' do
        mock_response.content = 'Paris is the capital of France.'
        response = chat.ask('What is the capital of France?')
        expect(response).to be_a(Message)
      end

      it 'creates correct message count with string input' do
        initial_count = chat.messages.count
        chat.ask('What is the capital of France?')
        expect(chat.messages.count).to eq(initial_count + 2)
      end

      it 'creates correct user message from string' do
        chat.ask('What is the capital of France?')
        user_message = chat.messages.where(role: 'user').last
        expect(user_message.content).to eq('What is the capital of France?')
      end
    end

    context 'with underlying chat interaction' do
      let(:user_message) do
        chat.messages.create!(
          role: 'user',
          content: 'Test message'
        )
      end

      let(:underlying_chat) { instance_double(RubyLLM::Chat) }

      before do
        allow(underlying_chat).to receive(:add_message)
        allow(underlying_chat).to receive(:complete) do
          chat.messages.create!(role: 'assistant', content: 'Response')
        end
        allow(chat).to receive(:to_llm).and_return(underlying_chat)
      end

      it 'calls add_message on the underlying chat' do
        chat.ask(user_message)
        expect(underlying_chat).to have_received(:add_message)
      end

      it 'passes a RubyLLM::Message to add_message' do
        chat.ask(user_message)
        expect(underlying_chat).to have_received(:add_message).with(an_instance_of(RubyLLM::Message))
      end

      it 'passes correct content to add_message' do
        chat.ask(user_message)
        expect(underlying_chat).to have_received(:add_message).with(
          having_attributes(content: 'Test message')
        )
      end

      it 'passes correct role to add_message' do
        chat.ask(user_message)
        expect(underlying_chat).to have_received(:add_message).with(
          having_attributes(role: :user)
        )
      end
    end

    context 'with error conditions' do
      it 'raises error for message object with attachments' do
        user_message = chat.messages.create!(role: 'user', content: 'Test')
        expect do
          chat.ask(user_message, with: ['some_file.txt'])
        end.to raise_error(ArgumentError, /Cannot provide attachments/)
      end

      it 'raises error for message from different chat' do
        other_chat = Chat.create!(model_id: 'gpt-4.1-nano')
        other_message = other_chat.messages.create!(role: 'user', content: 'Test')
        expect do
          chat.ask(other_message)
        end.to raise_error(ArgumentError, /Message belongs to a different chat/)
      end

      it 'raises an error when message object has nil role or content' do
        invalid_message = chat.messages.new(role: 'user', content: nil)
        expect do
          chat.ask(invalid_message)
        end.to raise_error(ArgumentError, /Message object must have non-nil role and content/)
      end
    end

    context 'with duck typing' do
      it 'works with Struct objects' do
        struct_message = Struct.new(:role, :content).new(:user, 'Hello from Struct!')
        response = chat.ask(struct_message)
        expect(response).to be_a(Message)
      end

      it 'creates correct message count with Struct' do
        struct_message = Struct.new(:role, :content).new(:user, 'Hello from Struct!')
        initial_count = chat.messages.count
        chat.ask(struct_message)
        expect(chat.messages.count).to eq(initial_count + 2)
      end
    end
  end
end
