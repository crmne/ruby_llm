# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_tool' do
    it 'adds tools regardless of model capabilities' do
      # Create a non-function-calling model by patching the supports_functions attribute
      model = RubyLLM.models.find('gpt-4.1-nano')
      allow(model).to receive(:supports_functions?).and_return(false)

      chat = described_class.new(model: 'gpt-4.1-nano')
      # Replace the model with our modified version
      chat.instance_variable_set(:@model, model)

      # Should not raise an error anymore
      expect do
        chat.with_tool(RubyLLM::Tool)
      end.not_to raise_error
    end
  end

  describe '#with_tools' do
    it 'adds multiple tools at once' do
      chat = described_class.new

      tool1 = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      tool2 = Class.new(RubyLLM::Tool) do
        def name = 'tool2'
      end

      chat.with_tools(tool1.new, tool2.new)

      expect(chat.tools.keys).to include(:tool1, :tool2)
      expect(chat.tools.size).to eq(2)
    end

    it 'replaces all tools when replace: true' do
      chat = described_class.new

      tool1 = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      tool2 = Class.new(RubyLLM::Tool) do
        def name = 'tool2'
      end

      tool3 = Class.new(RubyLLM::Tool) do
        def name = 'tool3'
      end

      # Add initial tools
      chat.with_tools(tool1.new, tool2.new)
      expect(chat.tools.size).to eq(2)

      # Replace with new tool
      chat.with_tools(tool3.new, replace: true)

      expect(chat.tools.keys).to eq([:tool3])
      expect(chat.tools.size).to eq(1)
    end

    it 'clears all tools when called with nil and replace: true' do
      chat = described_class.new

      tool1 = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      # Add initial tool
      chat.with_tool(tool1.new)
      expect(chat.tools.size).to eq(1)

      # Clear all tools
      chat.with_tools(nil, replace: true)

      expect(chat.tools).to be_empty
    end

    it 'clears all tools when called with no arguments and replace: true' do
      chat = described_class.new

      tool1 = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      # Add initial tool
      chat.with_tool(tool1.new)
      expect(chat.tools.size).to eq(1)

      # Clear all tools
      chat.with_tools(replace: true)

      expect(chat.tools).to be_empty
    end
  end

  describe '#with_model' do
    it 'changes the model and returns self' do
      chat = described_class.new(model: 'gpt-4.1-nano')
      result = chat.with_model('claude-3-5-haiku-20241022')

      expect(chat.model.id).to eq('claude-3-5-haiku-20241022')
      expect(result).to eq(chat) # Should return self for chaining
    end
  end

  describe '#with_temperature' do
    it 'sets the temperature and returns self' do
      chat = described_class.new
      result = chat.with_temperature(0.8)

      expect(chat.instance_variable_get(:@temperature)).to eq(0.8)
      expect(result).to eq(chat) # Should return self for chaining
    end
  end

  describe '#with_messages' do
    it 'adds multiple messages at once' do
      chat = described_class.new

      messages = [
        { role: :user, content: 'First message' },
        { role: :assistant, content: 'Second message' },
        { role: :user, content: 'Third message' }
      ]

      chat.with_messages(messages)

      expect(chat.messages.size).to eq(3)
      expect(chat.messages[0].role).to eq(:user)
      expect(chat.messages[0].content.to_s).to eq('First message')
      expect(chat.messages[1].role).to eq(:assistant)
      expect(chat.messages[1].content.to_s).to eq('Second message')
      expect(chat.messages[2].role).to eq(:user)
      expect(chat.messages[2].content.to_s).to eq('Third message')
    end

    it 'accepts Message objects' do
      chat = described_class.new

      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hello'),
        RubyLLM::Message.new(role: :assistant, content: 'Hi there')
      ]

      chat.with_messages(messages)

      expect(chat.messages).to match_array(messages)
    end

    it 'accepts a mix of Message objects and hashes' do
      chat = described_class.new

      messages = [
        RubyLLM::Message.new(role: :system, content: 'You are helpful'),
        { role: :user, content: 'What is 2+2?' },
        RubyLLM::Message.new(role: :assistant, content: '4')
      ]

      chat.with_messages(messages)

      expect(chat.messages.size).to eq(3)
      expect(chat.messages[0].role).to eq(:system)
      expect(chat.messages[1].role).to eq(:user)
      expect(chat.messages[2].role).to eq(:assistant)
    end

    it 'returns self for method chaining' do
      chat = described_class.new

      result = chat.with_messages([{ role: :user, content: 'Test' }])

      expect(result).to eq(chat)
    end

    it 'preserves message order' do
      chat = described_class.new

      messages = (1..5).map { |i| { role: :user, content: "Message #{i}" } }

      chat.with_messages(messages)

      chat.messages.each_with_index do |msg, i|
        expect(msg.content.to_s).to eq("Message #{i + 1}")
      end
    end

    it 'handles empty array' do
      chat = described_class.new

      chat.with_messages([])

      expect(chat.messages).to be_empty
    end

    it 'adds to existing messages' do
      chat = described_class.new
      chat.add_message(role: :system, content: 'Initial message')

      chat.with_messages([
                           { role: :user, content: 'New message 1' },
                           { role: :assistant, content: 'New message 2' }
                         ])

      expect(chat.messages.size).to eq(3)
      expect(chat.messages[0].content.to_s).to eq('Initial message')
      expect(chat.messages[1].content.to_s).to eq('New message 1')
      expect(chat.messages[2].content.to_s).to eq('New message 2')
    end

    it 'works with method chaining' do
      chat = described_class.new
                            .with_messages([{ role: :system, content: 'System prompt' }])
                            .with_temperature(0.7)
                            .with_messages([{ role: :user, content: 'User message' }])

      expect(chat.messages.size).to eq(2)
      expect(chat.instance_variable_get(:@temperature)).to eq(0.7)
    end
  end

  describe '#each' do
    it 'iterates through messages' do
      chat = described_class.new
      chat.add_message(role: :user, content: 'Message 1')
      chat.add_message(role: :assistant, content: 'Message 2')

      messages = chat.map do |msg|
        msg
      end

      expect(messages.size).to eq(2)
      expect(messages[0].content).to eq('Message 1')
      expect(messages[1].content).to eq('Message 2')
    end
  end
end
