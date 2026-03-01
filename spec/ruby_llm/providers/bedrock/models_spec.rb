# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Models do
  describe '.supports_structured_output?' do
    {
      'anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'anthropic.claude-sonnet-4-5-20250929-v1:0' => true,
      'anthropic.claude-opus-4-5-20250514-v1:0' => true,
      'us.anthropic.claude-opus-4-6-v1' => true,
      'eu.anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'global.anthropic.claude-haiku-4-5-20251001-v1:0' => true,
      'anthropic.claude-opus-4-20250514-v1:0' => false,
      'anthropic.claude-3-5-sonnet-20241022-v2:0' => false,
      'amazon.nova-2-lite-v1:0' => false,
      nil => false
    }.each do |model_id, expected|
      it "returns #{expected} for #{model_id.inspect}" do
        expect(described_class.supports_structured_output?(model_id)).to eq(expected)
      end
    end
  end
end
