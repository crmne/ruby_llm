# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '#name' do
    it 'converts class name to snake_case and removes _tool suffix' do
      class SampleTool < RubyLLM::Tool; end
      expect(SampleTool.new.name).to eq('sample')
    end

    it 'normalizes class name Unicode characters to ASCII' do
      class SàmpleTòol < RubyLLM::Tool; end
      expect(SàmpleTòol.new.name).to eq('sample')
    end

    it 'handles class names with unsupported characters' do
      class SampleΨTool < RubyLLM::Tool; end
      expect(SampleΨTool.new.name).to eq('sample')
    end

    it 'handles class names without Tool suffix' do
      class AnotherSample < RubyLLM::Tool; end
      expect(AnotherSample.new.name).to eq('another_sample')
    end

    it 'strips :: for class in module namespace' do
      module TestModule
        class SampleTool < RubyLLM::Tool; end
      end
      expect(TestModule::SampleTool.new.name).to eq('test_module--sample')
    end
  end
end
