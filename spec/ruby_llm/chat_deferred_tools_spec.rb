# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  before do
    stub_const('RegularTool', Class.new(RubyLLM::Tool) { description 'plain tool' })
    stub_const('HeavyTool', Class.new(RubyLLM::Tool) do
      description 'heavy deferred tool'
      defer
      def execute = 'heavy ran'
    end)
  end

  let(:chat) { described_class.new(model: model_for(:anthropic), provider: :anthropic) }

  def rendered_tools(chat)
    chat.render[:tools].map { |tool| tool.slice(:name, :type, :defer_loading) }
  end

  describe '#deferred_tools' do
    it 'returns the tools declared with Tool.defer' do
      chat.with_tools(RegularTool, HeavyTool)

      expect(chat.tools.keys).to eq(%i[regular heavy])
      expect(chat.deferred_tools.keys).to eq([:heavy])
      expect(chat.deferred_tools[:heavy]).to be(chat.tools[:heavy])
    end

    it 'defers every tool registered with defer: true' do
      chat.with_tools(RegularTool, HeavyTool, defer: true)

      expect(chat.deferred_tools.keys).to eq(%i[regular heavy])
    end

    it 'offers a deferred class up front with defer: false' do
      chat.with_tools(HeavyTool, defer: false)

      expect(chat.deferred_tools).to be_empty
    end

    it 'follows the latest registration of a name' do
      chat.with_tools(RegularTool, defer: true).with_tools(RegularTool)

      expect(chat.deferred_tools).to be_empty
    end

    it 'forgets deferrals when the tools are cleared' do
      chat.with_tools(RegularTool, defer: true).with_tools(nil).with_tools(RegularTool)

      expect(chat.deferred_tools).to be_empty
    end
  end

  describe 'requests' do
    it 'marks deferred tools and adds the search tool' do
      chat.with_tools(RegularTool, HeavyTool)

      expect(rendered_tools(chat)).to eq([{ name: 'regular' }, { name: 'heavy', defer_loading: true },
                                          { name: 'tool_search_tool_bm25', type: 'tool_search_tool_bm25_20251119' }])
    end

    it 'does not gate deferral on the model catalog' do
      chat.with_model(model_for(:anthropic), provider: :vertexai).with_tools(HeavyTool)
      allow(chat.model).to receive(:supports?).and_raise('Must not gate on model metadata')

      expect(rendered_tools(chat).first).to include(defer_loading: true)
    end

    it 'sends deferred tools as ordinary tools on a protocol without tool search' do
      chat.with_model(model_for(:gemini), provider: :gemini).with_tools(HeavyTool)

      expect(chat.render.to_json).not_to include('defer_loading')
      expect(chat.deferred_tools.keys).to eq([:heavy])
    end

    it 'keeps a search tool configured through provider tools instead of adding another' do
      regex = { type: 'tool_search_tool_regex_20251119', name: 'tool_search_tool_regex' }
      chat.with_tools(HeavyTool).with_provider_tools(regex)

      expect(rendered_tools(chat).last).to eq(regex)
      expect(rendered_tools(chat).count { |tool| tool[:type].to_s.start_with?('tool_search') }).to eq(1)
    end
  end

  it 'executes a deferred tool the model calls' do
    chat.with_tools(HeavyTool)
    tool_call = RubyLLM::ToolCall.new(id: 't1', name: 'heavy', arguments: {})

    expect(chat.send(:execute_tool, tool_call)).to eq('heavy ran')
  end
end
