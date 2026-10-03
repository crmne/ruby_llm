# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do
  it 'adds tool_search for gpt-5.4 and later Responses models' do
    %w[gpt-5.4 gpt-5.4-2026-03-05 gpt-5.5 gpt-5.6-sol gpt-6-astra gpt-6.1-sol].each do |id|
      capabilities = described_class.augment(%w[function_calling], model_id: id, modalities: { output: ['text'] })

      expect(capabilities).to include('tool_search'), id
    end
  end

  it 'does not add tool_search for earlier models' do
    %w[gpt-4.1 gpt-5 gpt-5.2 o3].each do |id|
      capabilities = described_class.augment(%w[function_calling], model_id: id, modalities: { output: ['text'] })

      expect(capabilities).not_to include('tool_search'), id
    end
  end

  it 'emits only capabilities the registry schema accepts, so rake models validates the refreshed registry' do
    capabilities = described_class.augment(%w[function_calling], model_id: 'gpt-5.4', modalities: { output: ['text'] })

    expect(capabilities).to include('tool_search')
    expect(capabilities - RubyLLM::Models::Schema::CAPABILITIES).to be_empty
  end

  it 'does not change the source capability list' do
    original = ['function_calling'].freeze

    described_class.augment(original, model_id: 'gpt-5.4', modalities: { output: ['text'] })

    expect(original).to eq(['function_calling'])
  end
end
