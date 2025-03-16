# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/tool'

RSpec.describe RubyLLM::Tool do
  describe '#name' do
    it 'converts class name to snake_case and removes _tool suffix' do
      class SampleTool < RubyLLM::Tool; end
      expect(SampleTool.new.name).to eq('sample')
    end

    it 'replaces unsupported characters with -' do
      class SampleTòol < RubyLLM::Tool; end
      expect(SampleTòol.new.name).to eq('sample_t-ol')
    end

    it 'handles class names with multiple unsupported characters' do
      class SàmpleTòolèr < RubyLLM::Tool; end
      expect(SàmpleTòolèr.new.name).to eq('s-mple_t-ol-r')
    end

    it 'handles class names without _tool suffix' do
      class AnotherSampleTool < RubyLLM::Tool; end
      expect(AnotherSampleTool.new.name).to eq('another_sample')
    end

    it 'handles class names with numbers and underscores' do
      class SampleTool123 < RubyLLM::Tool; end
      expect(SampleTool123.new.name).to eq('sample_tool123')
    end

    it 'strips :: for class in module namespace' do
      module TestModule
        class SampleTool < RubyLLM::Tool; end
      end
      expect(TestModule::SampleTool.new.name).to eq('test_module--sample')
    end
  end
end
