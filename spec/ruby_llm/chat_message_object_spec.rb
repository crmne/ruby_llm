# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Chat ask with message objects' do
  include_context 'with configured RubyLLM'
  
  describe RubyLLM::Chat do
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

    it 'accepts an existing message object in ask method' do
      # Create a message object manually
      message = RubyLLM::Message.new(
        role: :user,
        content: 'What is 2 + 2?'
      )
      
      # Pass the message object to ask
      response = chat.ask(message)
      
      expect(response.content).to eq('4')
      expect(chat.messages.count).to eq(2) # user message + assistant response
      expect(chat.messages.first.content).to eq('What is 2 + 2?')
      expect(chat.messages.first.role).to eq(:user)
    end

    it 'does not duplicate messages when passing message objects' do
      message = RubyLLM::Message.new(
        role: :user,
        content: 'Hello'
      )
      
      initial_count = chat.messages.count
      chat.ask(message)
      
      # Should only add the message once plus the assistant response
      expect(chat.messages.count).to eq(initial_count + 2)
      
      # Verify the message appears only once
      user_messages = chat.messages.select { |m| m.role == :user }
      expect(user_messages.count).to eq(1)
      expect(user_messages.first.content).to eq('Hello')
    end

    it 'still works with string input' do
      mock_response.content = 'Paris is the capital of France.'
      
      response = chat.ask('What is the capital of France?')
      
      expect(response.content).to include('Paris')
      expect(chat.messages.count).to eq(2)
      expect(chat.messages.first.content).to eq('What is the capital of France?')
      expect(chat.messages.first.role).to eq(:user)
    end

    it 'preserves message attributes when passing objects' do
      # Create a message with custom attributes
      message = RubyLLM::Message.new(
        role: :user,
        content: 'Test message',
        model_id: 'custom-model'
      )
      
      chat.ask(message)
      
      # The message in the chat should preserve the attributes
      user_message = chat.messages.first
      expect(user_message.content).to eq('Test message')
      expect(user_message.role).to eq(:user)
      expect(user_message.model_id).to eq('custom-model')
    end

    it 'raises an error when trying to pass both message object and attachments' do
      message = RubyLLM::Message.new(
        role: :user,
        content: 'Test message'
      )
      
      expect {
        chat.ask(message, with: ['some_file.txt'])
      }.to raise_error(ArgumentError, /Cannot provide attachments.*when passing a message object/)
    end
  end
end