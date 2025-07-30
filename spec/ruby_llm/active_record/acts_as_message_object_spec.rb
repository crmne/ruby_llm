# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ActiveRecord ask with message objects' do
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

    before do
      # Mock to avoid actual API calls but simulate message persistence
      allow_any_instance_of(RubyLLM::Chat).to receive(:complete) do |instance|
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

    it 'accepts an existing message record in ask method' do
      # Create a message record manually
      user_message = chat.messages.create!(
        role: 'user',
        content: 'What is 2 + 2?'
      )
      
      # Pass the existing message record to ask
      initial_count = chat.messages.count
      response = chat.ask(user_message)
      
      # Should not create a duplicate user message
      expect(chat.messages.count).to eq(initial_count + 1) # Only the assistant response
      expect(response).to be_a(Message) # ActiveRecord model
      
      # Verify the user message wasn't duplicated
      user_messages = chat.messages.where(role: 'user')
      expect(user_messages.count).to eq(1)
      expect(user_messages.first.id).to eq(user_message.id)
    end

    it 'preserves additional attributes when passing message objects' do
      # Create a migration to add rich_content column for this test
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.add_column :messages, :rich_content, :text unless Message.column_names.include?('rich_content')
      end
      Message.reset_column_information
      
      # Create a message with rich content
      user_message = chat.messages.create!(
        role: 'user',
        content: 'Hello world'
      )
      
      # Manually set rich_content after creation
      user_message.update_column(:rich_content, '<p>Hello <strong>world</strong></p>')
      
      # Ask with the existing message
      chat.ask(user_message)
      
      # Verify rich content is preserved
      user_message.reload
      expect(user_message.content).to eq('Hello world')
      expect(user_message.read_attribute(:rich_content)).to eq('<p>Hello <strong>world</strong></p>')
    end

    it 'handles messages already in the collection' do
      # Create and add a message
      user_message = chat.messages.create!(
        role: 'user',
        content: 'Test message'
      )
      
      # Message is already in collection, should not duplicate
      expect(chat.messages).to include(user_message)
      
      initial_count = chat.messages.count
      chat.ask(user_message)
      
      # Should only add assistant response
      expect(chat.messages.count).to eq(initial_count + 1)
      
      # Verify no duplicate user messages
      user_messages = chat.messages.where(role: 'user')
      expect(user_messages.count).to eq(1)
    end

    it 'still works with string input' do
      mock_response.content = 'Paris is the capital of France.'
      
      initial_count = chat.messages.count
      response = chat.ask('What is the capital of France?')
      
      expect(response).to be_a(Message) # ActiveRecord model
      expect(chat.messages.count).to eq(initial_count + 2) # user + assistant
      
      # Check the created user message
      user_message = chat.messages.where(role: 'user').last
      expect(user_message.content).to eq('What is the capital of France?')
    end

    it 'calls add_message on the underlying chat when passing an existing message' do
      user_message = chat.messages.create!(
        role: 'user',
        content: 'Test message'
      )
      
      # Create a double for the underlying chat to spy on add_message
      underlying_chat = instance_double(RubyLLM::Chat)
      allow(underlying_chat).to receive(:add_message)
      allow(underlying_chat).to receive(:complete) do
        # Simulate creating the assistant message
        chat.messages.create!(role: 'assistant', content: 'Response')
      end
      
      # Stub to_llm to return our double
      allow(chat).to receive(:to_llm).and_return(underlying_chat)
      
      # Call ask and verify add_message was called with the correct argument
      chat.ask(user_message)
      
      expect(underlying_chat).to have_received(:add_message) do |message|
        expect(message).to be_a(RubyLLM::Message)
        expect(message.content).to eq('Test message')
        expect(message.role).to eq(:user)
      end
    end

    it 'raises an error when trying to pass both message object and attachments' do
      user_message = chat.messages.create!(
        role: 'user',
        content: 'Test message'
      )
      
      expect {
        chat.ask(user_message, with: ['some_file.txt'])
      }.to raise_error(ArgumentError, /Cannot provide attachments.*when passing a message object/)
    end
  end
end