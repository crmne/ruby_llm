# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_tools' do
    it 'adds a single tool regardless of model capabilities' do
      model = RubyLLM.models.find('gpt-4.1-nano')
      allow(model).to receive(:supports_functions?).and_return(false)

      chat = described_class.new(model: 'gpt-4.1-nano')
      chat.instance_variable_set(:@model, model)

      expect do
        chat.with_tools(RubyLLM::Tool)
      end.not_to raise_error
    end

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

    it 'ignores nil entries mixed with tools' do
      chat = described_class.new
      tool = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      chat.with_tools(tool.new, nil)

      expect(chat.tools.keys).to eq([:tool1])
    end

    it 'returns self for chaining' do
      chat = described_class.new
      tool = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      expect(chat.with_tools(tool.new)).to be(chat)
    end

    it 'rejects nil, pointing to without_tools' do
      chat = described_class.new

      expect { chat.with_tools(nil) }.to raise_error(ArgumentError, /without_tools/)
    end
  end

  describe '#without_tools' do
    it 'replaces all tools when followed by with_tools' do
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

      chat.with_tools(tool1.new, tool2.new)
      expect(chat.tools.size).to eq(2)

      chat.without_tools.with_tools(tool3.new)

      expect(chat.tools.keys).to eq([:tool3])
      expect(chat.tools.size).to eq(1)
    end

    it 'clears the tools while leaving the tool options unchanged' do
      chat = described_class.new

      tool1 = Class.new(RubyLLM::Tool) do
        def name = 'tool1'
      end

      chat.with_tools(tool1.new).with_tool_options(calls: :one, concurrency: true)
      chat.without_tools

      expect(chat.tools).to be_empty
      expect(chat.tool_prefs).to eq(choice: nil, calls: :one)
      expect(chat.concurrency).to eq(:threads)
    end
  end

  describe '#with_tool_options' do
    it 'stores calls preference as :many or :one' do
      chat = described_class.new

      chat.with_tool_options(calls: :many)
      expect(chat.tool_prefs[:calls]).to eq(:many)

      chat.with_tool_options(calls: :one)
      expect(chat.tool_prefs[:calls]).to eq(:one)

      chat.with_tool_options(calls: 1)
      expect(chat.tool_prefs[:calls]).to eq(:one)
    end

    it 'raises for invalid calls values' do
      chat = described_class.new

      expect { chat.with_tool_options(calls: :single) }.to raise_error(
        ArgumentError,
        /Invalid calls value/
      )
    end

    it 'stores tool concurrency preferences' do
      chat = described_class.new

      chat.with_tool_options(concurrency: true)

      expect(chat.concurrency).to eq(:threads)
    end

    it 'accepts explicit tool concurrency modes' do
      chat = described_class.new

      chat.with_tool_options(concurrency: :fibers)
      expect(chat.concurrency).to eq(:fibers)

      chat.with_tool_options(concurrency: :threads)
      expect(chat.concurrency).to eq(:threads)
    end

    it 'clears tool concurrency preferences' do
      chat = described_class.new

      chat.with_tool_options(concurrency: true)
      chat.with_tool_options(concurrency: false)

      expect(chat.concurrency).to be_nil
    end

    it 'raises for unknown tool concurrency' do
      chat = described_class.new

      expect { chat.with_tool_options(concurrency: :warp_speed) }.to raise_error(
        ArgumentError,
        /Unknown tool concurrency/
      )
    end

    it 'leaves options passed as nil unchanged' do
      chat = described_class.new

      chat.with_tool_options(calls: :one, concurrency: :fibers)
      chat.with_tool_options(choice: :required)

      expect(chat.tool_prefs).to eq(choice: :required, calls: :one)
      expect(chat.concurrency).to eq(:fibers)
    end

    it 'returns self for chaining' do
      chat = described_class.new

      expect(chat.with_tool_options(calls: :one)).to be(chat)
    end

    it 'uses the configured tool concurrency by default' do
      original_tool_concurrency = RubyLLM.config.tool_concurrency
      RubyLLM.config.tool_concurrency = true

      chat = described_class.new

      expect(chat.concurrency).to eq(:threads)
    ensure
      RubyLLM.config.tool_concurrency = original_tool_concurrency
    end

    it 'accepts explicit configured tool concurrency modes' do
      original_tool_concurrency = RubyLLM.config.tool_concurrency
      RubyLLM.config.tool_concurrency = :fibers

      chat = described_class.new

      expect(chat.concurrency).to eq(:fibers)
    ensure
      RubyLLM.config.tool_concurrency = original_tool_concurrency
    end

    it 'allows chats to override configured tool concurrency' do
      original_tool_concurrency = RubyLLM.config.tool_concurrency
      RubyLLM.config.tool_concurrency = true

      chat = described_class.new.with_tool_options(concurrency: false)

      expect(chat.concurrency).to be_nil
    ensure
      RubyLLM.config.tool_concurrency = original_tool_concurrency
    end
  end

  describe '#without_tool_options' do
    it 'resets choice and calls to nil and concurrency to the configured default' do
      original_tool_concurrency = RubyLLM.config.tool_concurrency
      RubyLLM.config.tool_concurrency = :fibers

      chat = described_class.new
      chat.with_tool_options(choice: :required, calls: :one, concurrency: :threads)

      chat.without_tool_options

      expect(chat.tool_prefs).to eq(choice: nil, calls: nil)
      expect(chat.concurrency).to eq(:fibers)
    ensure
      RubyLLM.config.tool_concurrency = original_tool_concurrency
    end
  end

  describe '#with_model' do
    it 'changes the model and returns self' do
      chat = described_class.new(model: 'gpt-4.1-nano')
      result = chat.with_model('claude-haiku-4-5')

      expect(chat.model.id).to eq('claude-haiku-4-5')
      expect(result).to eq(chat) # Should return self for chaining
    end

    it 'resets to the configured default model with nil' do
      chat = described_class.new(model: 'claude-haiku-4-5')

      chat.with_model(nil)

      expect(chat.model.id).to eq(RubyLLM.config.default_model)
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

    it 'keeps system instructions in chronological message history' do
      chat = described_class.new

      chat.add_message(role: :user, content: 'Hi')
      chat.add_message(role: :assistant, content: 'Hello')
      chat.with_instructions('System')

      expect(chat.messages.map(&:role)).to eq(%i[user assistant system])
    end

    it 'continues a staged user turn when instructions are added after it' do
      chat = described_class.new

      chat.ask_later('Hi')
      chat.with_instructions('Be brief')

      expect(chat).not_to be_complete
    end

    it 'clears system instructions with without_instructions' do
      chat = described_class.new

      chat.with_instructions('Be helpful')
      chat.without_instructions

      expect(chat.messages.select { |msg| msg.role == :system }).to be_empty
    end

    it 'rejects nil, pointing to without_instructions' do
      chat = described_class.new

      expect { chat.with_instructions(nil) }.to raise_error(ArgumentError, /without_instructions/)
    end
  end

  describe '#with_temperature' do
    it 'sets the temperature and returns self' do
      chat = described_class.new
      result = chat.with_temperature(0.8)

      expect(chat.instance_variable_get(:@temperature)).to eq(0.8)
      expect(result).to eq(chat) # Should return self for chaining
    end

    it 'clears the temperature with without_temperature' do
      chat = described_class.new.with_temperature(0.8)

      chat.without_temperature

      expect(chat.instance_variable_get(:@temperature)).to be_nil
    end

    it 'rejects nil, pointing to without_temperature' do
      chat = described_class.new

      expect { chat.with_temperature(nil) }.to raise_error(ArgumentError, /without_temperature/)
    end
  end

  describe 'protocol override' do
    it 'sets @protocol from RubyLLM.chat(protocol:)' do
      chat = described_class.new(model: 'gpt-4.1-nano', protocol: :chat_completions)

      expect(chat.instance_variable_get(:@protocol)).to eq(:chat_completions)
    end

    it 'sets @protocol from with_model(id, protocol:)' do
      chat = described_class.new(model: 'gpt-4.1-nano')

      chat.with_model('gpt-4.1-nano', protocol: :chat_completions)

      expect(chat.instance_variable_get(:@protocol)).to eq(:chat_completions)
    end

    it 'resets @protocol to nil when with_model is called without a protocol' do
      chat = described_class.new(model: 'gpt-4.1-nano', protocol: :chat_completions)

      chat.with_model('gpt-4.1-nano')

      expect(chat.instance_variable_get(:@protocol)).to be_nil
    end
  end

  describe '#messages=' do
    it 'replaces the transcript with coerced messages' do
      chat = described_class.new
      old_message = chat.add_message(role: :user, content: 'Old')
      assistant_message = RubyLLM::Message.new(role: :assistant, content: 'Answer')
      record = double(to_llm: RubyLLM::Message.new(role: :user, content: 'From record'))

      chat.messages = [
        { role: :system, content: 'Instructions' },
        assistant_message,
        record
      ]

      expect(chat.messages).not_to include(old_message)
      expect(chat.messages[1]).to be(assistant_message)
      expect(chat.messages.map(&:role)).to eq(%i[system assistant user])
      expect(chat.messages.map(&:content)).to eq(['Instructions', 'Answer', 'From record'])
    end

    it 'accepts a single message payload' do
      chat = described_class.new

      chat.messages = { role: :user, content: 'Only message' }

      expect(chat.messages.size).to eq(1)
      expect(chat.messages.first).to be_a(RubyLLM::Message)
      expect(chat.messages.first.content).to eq('Only message')
    end

    it 'clears the transcript when assigned nil' do
      chat = described_class.new
      chat.add_message(role: :user, content: 'Hello')

      chat.messages = nil

      expect(chat.messages).to be_empty
    end

    it 'does not use the assigned array as backing storage' do
      chat = described_class.new
      assigned = [RubyLLM::Message.new(role: :user, content: 'Hello')]

      chat.messages = assigned
      assigned << RubyLLM::Message.new(role: :assistant, content: 'Leaked')

      expect(chat.messages.map(&:content)).to eq(['Hello'])
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
