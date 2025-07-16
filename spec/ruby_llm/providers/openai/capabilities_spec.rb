# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.normalize_temperature' do
    it 'forces temperature to 1.0 for O1 models' do
      o1_models = %w[o1 o1-mini o1-preview o3-mini]

      o1_models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(1.0)
      end
    end

    it 'returns nil for search preview models' do
      search_models = %w[gpt-4o-search-preview gpt-4o-mini-search-preview]

      search_models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to be_nil
      end
    end

    it 'preserves temperature for standard models' do
      standard_models = ['gpt-4', 'gpt-4o', 'gpt-4o-mini', 'claude-3-opus']

      standard_models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(0.7)
      end
    end
  end
end
