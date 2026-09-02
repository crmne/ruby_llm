# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  subject(:chat) { RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai) }

  include_context 'with configured RubyLLM'

  describe '#with_tool_options' do
    it 'rejects an option it does not know' do
      expect { chat.with_tool_options(retries: 3) }.to raise_error(
        ArgumentError, /Unknown tool option: retries\. Valid options are: choice, calls, concurrency/
      )
    end

    it 'clears the recorded preferences when given nil' do
      chat.with_tool_options(choice: :auto, calls: :one)

      chat.with_tool_options(choice: nil, calls: nil)

      expect(chat.instance_variable_get(:@tool_prefs)).to eq(choice: nil, calls: nil)
    end

    it 'falls back to the configured concurrency when given nil' do
      chat.with_tool_options(concurrency: :threads)

      chat.with_tool_options(concurrency: nil)

      expect(chat.instance_variable_get(:@concurrency)).to be_nil
    end

    it 'reads true as threads' do
      chat.with_tool_options(concurrency: true)

      expect(chat.instance_variable_get(:@concurrency)).to eq(:threads)
    end

    it 'rejects a concurrency mode it does not know' do
      expect { chat.with_tool_options(concurrency: :processes) }.to raise_error(
        ArgumentError, /Unknown tool concurrency: :processes/
      )
    end
  end

  describe 'tool choice' do
    let(:lookup_tool) do
      stub_const('LookupTool', Class.new(RubyLLM::Tool) do
        def execute(query:) = query
      end)
      LookupTool
    end

    it 'accepts a tool class' do
      chat.with_tools(lookup_tool)

      chat.with_tool_options(choice: lookup_tool)

      expect(chat.instance_variable_get(:@tool_prefs)[:choice]).to eq(:lookup)
    end

    it 'accepts a tool instance' do
      chat.with_tools(lookup_tool)

      chat.with_tool_options(choice: lookup_tool.new)

      expect(chat.instance_variable_get(:@tool_prefs)[:choice]).to eq(:lookup)
    end

    it 'rejects a tool the chat does not carry' do
      expect { chat.with_tool_options(choice: :missing) }.to raise_error(
        RubyLLM::InvalidToolChoiceError, /Invalid tool choice: missing/
      )
    end

    it 'names an unregistered tool class the way the tool itself would' do
      stub_const('Support::LookupTool', Class.new(RubyLLM::Tool) do
        def execute(query:) = query
      end)
      chat.with_tools(lookup_tool)

      expect { chat.with_tool_options(choice: Support::LookupTool) }.to raise_error(
        RubyLLM::InvalidToolChoiceError, /Invalid tool choice: Support::LookupTool/
      )
    end
  end

  describe '#add_message' do
    it 'accepts an attributes hash, a Message, and anything convertible' do
      convertible = Struct.new(:to_llm).new(RubyLLM::Message.new(role: :user, content: 'converted'))

      chat.add_message(role: :user, content: 'hash')
      chat.add_message(RubyLLM::Message.new(role: :user, content: 'message'))
      chat.add_message(convertible)

      expect(chat.messages.map(&:content)).to eq(%w[hash message converted])
    end
  end

  describe '#messages=' do
    it 'accepts nothing, one message, or a list' do
      chat.messages = nil
      expect(chat.messages).to eq([])

      chat.messages = RubyLLM::Message.new(role: :user, content: 'one')
      expect(chat.messages.map(&:content)).to eq(['one'])

      chat.messages = [
        RubyLLM::Message.new(role: :user, content: 'a'),
        RubyLLM::Message.new(role: :assistant, content: 'b')
      ]
      expect(chat.messages.map(&:content)).to eq(%w[a b])
    end

    it 'accepts a single attributes hash' do
      chat.messages = { role: :user, content: 'hash' }

      expect(chat.messages.map(&:content)).to eq(['hash'])
    end
  end

  describe '#with_schema' do
    it 'passes a non-hash schema through untouched' do
      schema_class = Schematist::Schema.create { string :city }

      chat.with_schema(schema_class)

      expect(chat.instance_variable_get(:@schema)[:schema]).to include(:properties)
    end

    it 'reads strict off the wrapper' do
      chat.with_schema({ name: 'Person', schema: { type: 'object' }, strict: false })

      expect(chat.instance_variable_get(:@schema)[:strict]).to be(false)
    end

    it 'reads strict out of the inner schema' do
      chat.with_schema({ name: 'Person', schema: { type: 'object', strict: true } })

      payload = chat.instance_variable_get(:@schema)
      expect(payload[:strict]).to be(true)
      expect(payload[:schema]).not_to have_key(:strict)
    end

    it 'defaults to strict when every property is required' do
      chat.with_schema({
                         type: 'object',
                         properties: { name: { type: 'string' } },
                         required: ['name'],
                         additionalProperties: false
                       })

      expect(chat.instance_variable_get(:@schema)[:strict]).to be(true)
    end

    it 'defaults to non-strict when a property is optional' do
      schema_class = Class.new(Schematist::Schema) do
        string :name
        string :city, required: false
      end

      chat.with_schema(schema_class)

      expect(chat.instance_variable_get(:@schema)[:strict]).to be(false)
    end

    it 'defaults to non-strict when a nested object has optional properties' do
      chat.with_schema({
                         type: 'object',
                         properties: {
                           address: {
                             type: 'object',
                             properties: { street: { type: 'string' }, unit: { type: 'string' } },
                             required: ['street']
                           }
                         },
                         required: ['address']
                       })

      expect(chat.instance_variable_get(:@schema)[:strict]).to be(false)
    end

    it 'names an unnamed schema' do
      chat.with_schema({ type: 'object' })

      expect(chat.instance_variable_get(:@schema)[:name]).to eq('response')
    end

    it 'sanitizes an unusable schema name' do
      chat.with_schema({ name: 'Person Schema!', schema: { type: 'object' } })

      expect(chat.instance_variable_get(:@schema)[:name]).to eq('Person_Schema_')
    end

    it 'falls back to a generic name when nothing survives sanitizing' do
      chat.with_schema({ name: '', schema: { type: 'object' } })

      expect(chat.instance_variable_get(:@schema)[:name]).to eq('response')
    end

    it 'clears the schema when given nil' do
      chat.with_schema({ type: 'object' })

      chat.with_schema(nil)

      expect(chat.instance_variable_get(:@schema)).to be_nil
    end
  end

  describe '#thinking' do
    it 'returns nil when thinking is not configured' do
      expect(chat.thinking).to be_nil
    end

    it 'returns the options configured for the current model' do
      chat.with_thinking(effort: :high, budget: 2_000)

      expect(chat.thinking).to eq(effort: 'high', budget: 2_000)
    end
  end

  describe 'callbacks without a block' do
    it 'registers nothing' do
      chat.before_message

      expect(chat.instance_variable_get(:@callbacks)[:before_message]).to be_empty
    end
  end

  describe '#cancel' do
    it 'raises on the next completion attempt' do
      chat.cancel

      expect { chat.send(:raise_if_cancelled!) }.to raise_error(RubyLLM::CancelledError)
      expect(chat).not_to be_cancelled
    end

    it 'consults an external cancellation checker' do
      chat.cancellation_checker = -> { :cancelled }

      expect { chat.send(:raise_if_cancelled!) }.to raise_error(RubyLLM::CancelledError)
    end

    it 'continues when nothing has been cancelled' do
      chat.cancellation_checker = -> {}

      expect { chat.send(:raise_if_cancelled!) }.not_to raise_error
    end
  end

  describe '#add_completion' do
    it 'runs the message callbacks for a response produced out of band' do
      seen = []
      chat.before_message { seen << :before }
      chat.after_message { |message| seen << message.content }
      response = RubyLLM::Message.new(role: :assistant, content: 'from a batch')

      chat.add_completion(response)

      expect(seen).to eq([:before, 'from a batch'])
      expect(chat.messages.last).to eq(response)
    end
  end

  describe 'tool choice by class' do
    it 'derives the tool name from a class the chat does not carry' do
      stub_const('WeatherTool', Class.new(RubyLLM::Tool) do
        def execute(city:) = city
      end)
      chat.with_tools(WeatherTool)
      other = Class.new(RubyLLM::Tool) { def execute = 'ok' }
      stub_const('WeatherTool2', other)

      expect { chat.with_tool_options(choice: WeatherTool2) }.to raise_error(
        RubyLLM::InvalidToolChoiceError, /Invalid tool choice/
      )
    end
  end

  describe '#add_completion with usage already recorded' do
    it 'leaves the ledger alone' do
      response = RubyLLM::Message.new(role: :assistant, content: 'from a batch', input_tokens: 5, output_tokens: 2)
      allow(response).to receive(:ruby_llm_usage_entries).and_return([:already_recorded])

      chat.add_completion(response)

      expect(chat.usage_entries).to be_empty
    end
  end
end
