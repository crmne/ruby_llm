# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  subject(:chat) { described_class.new(model: 'claude-haiku-4-5', provider: :anthropic) }

  include_context 'with configured RubyLLM'

  def tool_class(const_name, desc, declared: false)
    klass = Class.new(RubyLLM::Tool) do
      description desc
      deferred if declared
    end
    stub_const(const_name, klass)
    klass
  end

  let(:regular) { tool_class('RegularTool', 'plain tool') }
  let(:heavy)   { tool_class('HeavyTool',   'heavy deferred tool', declared: true) }
  let(:another) { tool_class('OtherTool',   'another deferred tool') }

  describe '#with_tool' do
    it 'puts non-deferred tools on the active list' do
      chat.with_tool(regular)
      expect(chat.tools.keys).to include(:regular)
      expect(chat.tool_catalog).to be_empty
    end

    it 'routes class-declared deferred tools into the catalog without adding to active tools' do
      chat.with_tool(heavy)
      expect(chat.tool_catalog.deferred_tools.keys).to eq([:heavy])
      expect(chat.tools).to be_empty
    end

    it 'per-call defer: true overrides a non-declared class' do
      chat.with_tool(another, defer: true)
      expect(chat.tool_catalog.deferred_tools.keys).to eq([:other])
    end

    it 'per-call defer: false overrides a declared class' do
      chat.with_tool(heavy, defer: false)
      expect(chat.tools.keys).to include(:heavy)
      expect(chat.tool_catalog).to be_empty
    end
  end

  describe '#with_tools' do
    it 'routes each tool based on effective defer value' do
      chat.with_tools(regular, heavy, another, defer: true)
      expect(chat.tool_catalog.deferred_tools.keys).to match_array(%i[regular heavy other])
      expect(chat.tools).to be_empty
    end

    it 'clears both active and catalog when replace: true' do
      chat.with_tools(heavy, another, defer: true)
      chat.with_tools(regular, replace: true)
      expect(chat.tool_catalog).to be_empty
      expect(chat.tools.keys).to contain_exactly(:regular)
    end
  end

  describe 'tool_search_enabled kill switch' do
    before { allow(RubyLLM.logger).to receive(:warn) }

    around do |example|
      RubyLLM.config.tool_search_enabled = false
      example.run
    ensure
      RubyLLM.config.tool_search_enabled = true
    end

    it 'silently coerces defer: true to false and logs a warning once' do
      chat.with_tools(heavy, another, defer: true)
      expect(chat.tool_catalog).to be_empty
      expect(chat.tools.keys).to match_array(%i[heavy other])
      expect(RubyLLM.logger).to have_received(:warn).with(/tool_search_enabled is false/).once
    end
  end

  describe 'provider without deferred loading support' do
    subject(:openai_chat) do
      described_class.new(model: 'gpt-5.4', assume_model_exists: true, provider: :openai)
    end

    before { allow(RubyLLM.logger).to receive(:warn) }

    it 'coerces defer: true to regular registration and logs a warning once' do
      openai_chat.with_tools(heavy, another, defer: true)

      expect(openai_chat.tool_catalog).to be_empty
      expect(openai_chat.tools.keys).to match_array(%i[heavy other])
      expect(RubyLLM.logger).to have_received(:warn).with(/openai.*does not support deferred/i).once
    end
  end
end
