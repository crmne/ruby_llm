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

  describe '#with_instructions' do
    it 'replaces existing system instructions by default' do
      chat = described_class.new

      chat.with_instructions('Be helpful')
      chat.with_instructions('Be concise')

      system_messages = chat.messages.select { |msg| msg.role == :system }
      expect(system_messages.size).to eq(1)
      expect(system_messages.first.content).to eq('Be concise')
    end

    it 'appends system instructions when append: true' do
      chat = described_class.new

      chat.with_instructions('Be helpful')
      chat.with_instructions('Be concise', append: true)

      system_messages = chat.messages.select { |msg| msg.role == :system }
      expect(system_messages.map(&:content)).to eq(['Be helpful', 'Be concise'])
    end

    it 'keeps system instructions at the top of message history' do
      chat = described_class.new

      chat.add_message(role: :user, content: 'Hi')
      chat.add_message(role: :assistant, content: 'Hello')
      chat.with_instructions('System')

      expect(chat.messages.map(&:role)).to eq(%i[system user assistant])
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
