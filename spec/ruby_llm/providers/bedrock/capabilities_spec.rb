# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Capabilities do
  describe '.augment' do
    it 'includes documented tool choice for Nova 2 Lite and its US inference profile' do
      %w[amazon.nova-2-lite-v1:0 us.amazon.nova-2-lite-v1:0].each do |model_id|
        capabilities = described_class.augment(['function_calling'], model_id: model_id)

        expect(capabilities).to include('tool_choice')
        expect(capabilities).not_to include('parallel_tool_calls', 'structured_output')
      end
    end

    it 'does not infer tool controls for another model' do
      capabilities = described_class.augment([], model_id: 'amazon.titan-embed-text-v2:0')

      expect(capabilities).to eq([])
    end

    it 'does not change the source capability list' do
      original = ['function_calling'].freeze

      described_class.augment(original, model_id: 'amazon.nova-2-lite-v1:0')

      expect(original).to eq(['function_calling'])
    end
  end
end
