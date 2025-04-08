# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Capabilities do
  describe '.additional_headers_for_model' do
    it 'returns the beta header for claude-3-7-sonnet-20250219' do
      result = described_class.additional_headers_for_model('claude-3-7-sonnet-20250219')
      expect(result).to eq('anthropic-beta' => 'output-128k-2025-02-19')
    end

    it 'returns an empty hash for other models' do
      other_models = ['claude-3-5-sonnet-20241022', 'claude-3-haiku', 'claude-2']

      other_models.each do |model|
        result = described_class.additional_headers_for_model(model)
        expect(result).to eq({})
      end
    end
  end
end
