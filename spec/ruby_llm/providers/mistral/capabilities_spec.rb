# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Capabilities do
  describe '.augment' do
    it 'includes documented structured output for Small 4 and its current alias' do
      %w[mistral-small-2603 mistral-small-latest].each do |model_id|
        capabilities = described_class.augment(%w[function_calling reasoning vision], model_id: model_id)

        expect(capabilities).to include('structured_output', 'tool_choice', 'parallel_tool_calls')
      end
    end

    it 'does not give document models chat structured output' do
      capabilities = described_class.augment(['vision'], model_id: 'mistral-ocr-latest')

      expect(capabilities).to eq(['vision'])
    end

    it 'does not change the source capability list' do
      capabilities = %w[function_calling reasoning].freeze

      described_class.augment(capabilities, model_id: 'mistral-small-latest')

      expect(capabilities).to eq(%w[function_calling reasoning])
    end
  end
end
