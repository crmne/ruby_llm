# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ToolCatalog do
  let(:foo) { build_tool('FooTool', 'finds foo things') }
  let(:bar) { build_tool('BarTool', 'finds bar things') }

  def build_tool(const_name, desc)
    stub_const(const_name, Class.new(RubyLLM::Tool) { description(desc) })
    Object.const_get(const_name).new
  end

  describe '#empty? / #any?' do
    it 'starts empty' do
      catalog = described_class.new
      expect(catalog).to be_empty
      expect(catalog.any?).to be(false)
    end

    it 'reports non-empty after add' do
      catalog = described_class.new.add(foo)
      expect(catalog).not_to be_empty
      expect(catalog.any?).to be(true)
    end
  end

  describe '#add' do
    it 'keys tools by their snake_case name' do
      catalog = described_class.new
      catalog.add(foo)
      expect(catalog.deferred_tools.keys).to eq([:foo])
    end

    it 'overwrites on duplicate name' do
      stub_const('FooTool', Class.new(RubyLLM::Tool) { description('v1') })
      first = FooTool.new
      stub_const('FooTool', Class.new(RubyLLM::Tool) { description('v2') })
      second = FooTool.new

      catalog = described_class.new.add(first).add(second)
      expect(catalog.deferred_tools.size).to eq(1)
      expect(catalog.deferred_tools[:foo].description).to eq('v2')
    end
  end

  describe '#promote' do
    it 'records the tool as loaded and returns it' do
      catalog = described_class.new.add(foo).add(bar)
      expect(catalog.promote(:foo)).to eq(foo)
      expect(catalog.loaded_tools).to contain_exactly(:foo)
    end

    it 'accepts string names' do
      catalog = described_class.new.add(foo)
      expect(catalog.promote('foo')).to eq(foo)
      expect(catalog.loaded_tools).to include(:foo)
    end

    it 'returns nil for unknown names and does not record them' do
      catalog = described_class.new.add(foo)
      expect(catalog.promote(:missing)).to be_nil
      expect(catalog.loaded_tools).to be_empty
    end
  end

  describe '#available' do
    it 'excludes tools already promoted' do
      catalog = described_class.new.add(foo).add(bar)
      catalog.promote(:foo)
      expect(catalog.available.keys).to contain_exactly(:bar)
    end
  end

  describe '#inspect' do
    it 'reports counts' do
      catalog = described_class.new.add(foo).add(bar)
      catalog.promote(:foo)
      expect(catalog.inspect).to eq('#<RubyLLM::ToolCatalog deferred=2 loaded=1>')
    end
  end
end
