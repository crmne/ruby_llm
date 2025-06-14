# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_tool unsupported functions' do
    it "raises UnsupportedFunctionsError when model doesn't support functions" do # rubocop:disable RSpec/ExampleLength
      # Create a non-function-calling model by patching the supports_functions attribute
      model = RubyLLM.models.find('gpt-4.1-nano')
      allow(model).to receive(:supports_functions?).and_return(false)

      chat = described_class.new(model: 'gpt-4.1-nano')
      # Replace the model with our modified version
      chat.instance_variable_set(:@model, model)

      expect do
        chat.with_tool(RubyLLM::Tool)
      end.to raise_error(RubyLLM::UnsupportedFunctionsError, /doesn't support function calling/)
    end
  end

  describe '#with_tools' do
    it 'adds multiple tools at once' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
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
  end

  describe '#with_model' do
    it 'changes the model and returns self' do # rubocop:disable RSpec/MultipleExpectations
      chat = described_class.new(model: 'gpt-4.1-nano')
      result = chat.with_model('claude-3-5-haiku-20241022')

      expect(chat.model.id).to eq('claude-3-5-haiku-20241022')
      expect(result).to eq(chat) # Should return self for chaining
    end
  end

  describe '#with_temperature' do
    it 'sets the temperature and returns self' do # rubocop:disable RSpec/MultipleExpectations
      chat = described_class.new
      result = chat.with_temperature(0.8)

      expect(chat.instance_variable_get(:@temperature)).to eq(0.8)
      expect(result).to eq(chat) # Should return self for chaining
    end
  end

  describe '#each' do
    it 'iterates through messages' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
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
