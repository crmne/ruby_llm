# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Capabilities do
  describe '.model_family' do
    it 'identifies Claude 4.x model families' do
      {
        'anthropic.claude-opus-4-5-20251101-v1:0' => :claude_opus_4_5,
        'anthropic.claude-opus-4-20250514-v1:0' => :claude_opus_4,
        'anthropic.claude-sonnet-4-5-20250929-v1:0' => :claude_sonnet_4_5,
        'anthropic.claude-sonnet-4-20250514-v1:0' => :claude_sonnet_4,
        'anthropic.claude-haiku-4-5-20251001-v1:0' => :claude_haiku_4_5
      }.each do |model_id, expected_family|
        expect(described_class.model_family(model_id)).to eq(expected_family)
      end
    end

    it 'identifies Claude 4.x model families with region prefix' do
      {
        'us.anthropic.claude-opus-4-5-20251101-v1:0' => :claude_opus_4_5,
        'us.anthropic.claude-opus-4-20250514-v1:0' => :claude_opus_4,
        'eu.anthropic.claude-sonnet-4-5-20250929-v1:0' => :claude_sonnet_4_5,
        'ap.anthropic.claude-sonnet-4-20250514-v1:0' => :claude_sonnet_4,
        'us.anthropic.claude-haiku-4-5-20251001-v1:0' => :claude_haiku_4_5
      }.each do |model_id, expected_family|
        expect(described_class.model_family(model_id)).to eq(expected_family)
      end
    end

    it 'identifies Claude 3.x model families' do
      {
        'anthropic.claude-3-opus-20240229-v1:0' => :claude3_opus,
        'anthropic.claude-3-5-sonnet-20241022-v2:0' => :claude3_sonnet,
        'anthropic.claude-3-7-sonnet-20250219-v1:0' => :claude3_sonnet,
        'anthropic.claude-3-haiku-20240307-v1:0' => :claude3_haiku,
        'anthropic.claude-3-5-haiku-20241022-v1:0' => :claude3_5_haiku
      }.each do |model_id, expected_family|
        expect(described_class.model_family(model_id)).to eq(expected_family)
      end
    end
  end

  describe '.input_price_for and .output_price_for' do
    it 'returns correct pricing for Claude 4.x models' do
      {
        'us.anthropic.claude-opus-4-5-20251101-v1:0' => { input: 5.0, output: 25.0 },
        'us.anthropic.claude-opus-4-20250514-v1:0' => { input: 15.0, output: 75.0 },
        'us.anthropic.claude-sonnet-4-5-20250929-v1:0' => { input: 3.0, output: 15.0 },
        'us.anthropic.claude-sonnet-4-20250514-v1:0' => { input: 3.0, output: 15.0 },
        'us.anthropic.claude-haiku-4-5-20251001-v1:0' => { input: 1.0, output: 5.0 }
      }.each do |model_id, expected_prices|
        expect(described_class.input_price_for(model_id)).to eq(expected_prices[:input])
        expect(described_class.output_price_for(model_id)).to eq(expected_prices[:output])
      end
    end
  end
end
