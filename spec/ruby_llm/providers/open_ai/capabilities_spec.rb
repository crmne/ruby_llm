# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do
  describe '.normalize_temperature' do
    it 'forces temperature to 1.0 for O1 models' do
      %w[o1 o1-mini o1-preview o3-mini].each do |model|
        expect(described_class.normalize_temperature(0.7, model)).to eq(1.0)
      end
    end

    it 'returns nil for search preview models' do
      %w[gpt-4o-search-preview gpt-4o-mini-search-preview].each do |model|
        expect(described_class.normalize_temperature(0.7, model)).to be_nil
      end
    end

    it 'preserves temperature for standard models' do
      %w[gpt-4 gpt-4o gpt-4o-mini claude-3-opus].each do |model|
        expect(described_class.normalize_temperature(0.7, model)).to eq(0.7)
      end
    end
  end
end
