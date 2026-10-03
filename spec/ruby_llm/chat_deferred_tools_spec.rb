# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def define_tools!
    stub_const('RegularTool', Class.new(RubyLLM::Tool) { description 'plain tool' })
    stub_const('HeavyTool', Class.new(RubyLLM::Tool) do
      description 'heavy deferred tool'
      deferred
      def execute = 'heavy ran'
    end)
    stub_const('OtherTool', Class.new(RubyLLM::Tool) { description 'another tool' })
  end

  before { define_tools! }

  def anthropic_chat
    described_class.new(model: 'claude-haiku-4-5', provider: :anthropic)
  end

  def old_anthropic_chat
    described_class.new(model: 'claude-opus-4-1', provider: :anthropic, assume_model_exists: true)
  end

  def deferred_names(chat)
    chat.instance_variable_get(:@deferred_tool_names).keys
  end

  def chat_completions_chat
    described_class.new(model: 'gpt-5.4', provider: :openai, protocol: :chat_completions)
  end

  describe '#with_tools' do
    it 'lists every registered tool, deferred or not' do
      chat = anthropic_chat.with_tools(RegularTool, HeavyTool)
      expect(chat.tools.keys).to eq(%i[regular heavy])
      expect(deferred_names(chat)).to eq([:heavy])
    end

    it 'defers a tool declared deferred' do
      chat = anthropic_chat.with_tools(HeavyTool)
      expect(deferred_names(chat)).to include(:heavy)
    end

    it 'defers any tool with defer: true' do
      chat = anthropic_chat.with_tools(RegularTool, HeavyTool, OtherTool, defer: true)
      expect(deferred_names(chat)).to match_array(%i[regular heavy other])
    end

    it 'treats a truthy defer: as true' do
      chat = anthropic_chat.with_tools(OtherTool, defer: 1)
      expect(deferred_names(chat)).to include(:other)
    end

    it 'overrides a deferred class with defer: false' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: false)
      expect(chat.tools.keys).to eq([:heavy])
      expect(deferred_names(chat)).to be_empty
    end

    it 'lets the latest registration of a name decide' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true).with_tools(HeavyTool, defer: false)
      expect(chat.tools.keys).to eq([:heavy])
      expect(deferred_names(chat)).to be_empty

      chat.with_tools(HeavyTool, defer: true)
      expect(chat.tools.keys).to eq([:heavy])
      expect(deferred_names(chat)).to include(:heavy)
    end

    it 'records defer intent on a provider without tool search' do
      chat = chat_completions_chat.with_tools(HeavyTool, defer: true)
      expect(deferred_names(chat)).to include(:heavy)
    end

    it 'registers a tool without deferred? when defer is not requested' do
      duck = Object.new
      def duck.name = 'duck'

      expect { anthropic_chat.with_tools(duck) }.not_to raise_error
    end

    it 'clears the deferred tools along with the rest on nil' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true).with_tools(RegularTool)
      chat.with_tools(nil)
      expect(chat.tools).to be_empty
      expect(deferred_names(chat)).to be_empty
    end
  end

  describe '#effective_tools' do
    it 'returns the tools unchanged when nothing is deferred' do
      chat = anthropic_chat.with_tools(RegularTool)
      expect(chat.send(:effective_tools)).to eq(chat.tools)
    end

    it 'wraps deferred tools in a deferred Registration on a model with tool search' do
      chat = anthropic_chat.with_tools(RegularTool).with_tools(HeavyTool, defer: true)
      effective = chat.send(:effective_tools)

      expect(effective.keys).to eq(%i[regular heavy])
      expect(effective[:heavy]).to be_a(RubyLLM::Tool::Registration)
      expect(effective[:heavy].deferred?).to be(true)
      expect(effective[:regular]).not_to be_a(RubyLLM::Tool::Registration)
    end

    it 'sends deferred tools as ordinary tools on a model without tool search, without logging' do
      allow(RubyLLM.logger).to receive(:warn)
      chat = old_anthropic_chat.with_tools(HeavyTool, OtherTool, defer: true)

      effective = chat.send(:effective_tools)

      expect(effective.keys).to eq(%i[heavy other])
      expect(effective.values).to all(be_a(RubyLLM::Tool))
      expect(effective.values).not_to include(a_kind_of(RubyLLM::Tool::Registration))
      expect(RubyLLM.logger).not_to have_received(:warn)
    end

    it 'sends them as ordinary tools on a protocol without tool search' do
      chat = chat_completions_chat.with_tools(HeavyTool, defer: true)
      expect(chat.send(:effective_tools)[:heavy]).not_to be_a(RubyLLM::Tool::Registration)
    end

    it 'follows the current model across #with_model switches' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true)
      expect(chat.send(:effective_tools)[:heavy]).to be_a(RubyLLM::Tool::Registration)

      chat.with_model('claude-opus-4-1', provider: :anthropic, assume_model_exists: true)
      expect(chat.send(:effective_tools)[:heavy]).not_to be_a(RubyLLM::Tool::Registration)

      chat.with_model('claude-haiku-4-5', provider: :anthropic)
      expect(chat.send(:effective_tools)[:heavy]).to be_a(RubyLLM::Tool::Registration)
    end
  end

  describe 'tool choice' do
    it 'accepts a deferred tool as a named choice' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true)
      expect { chat.with_tool_options(choice: :heavy) }.not_to raise_error
      expect(chat.tool_prefs[:choice]).to eq(:heavy)
    end

    it 'still rejects unknown tool names' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true)
      expect { chat.with_tool_options(choice: :missing) }.to raise_error(RubyLLM::InvalidToolChoiceError)
    end
  end

  describe 'dispatch' do
    it 'executes a deferred tool the model calls' do
      chat = anthropic_chat.with_tools(HeavyTool, defer: true)
      tool_call = RubyLLM::ToolCall.new(id: 't1', name: 'heavy', arguments: {})

      expect(chat.send(:execute_tool, tool_call)).to eq('heavy ran')
    end
  end
end
