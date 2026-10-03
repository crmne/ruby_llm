# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Capabilities do
  it 'adds tool_search for the models Anthropic lists for its tool search tool' do
    %w[claude-haiku-4-5 claude-haiku-4-5-20251001 claude-opus-4-8 claude-sonnet-4-6 claude-fable-5-1].each do |id|
      capabilities = described_class.augment(%w[function_calling], model_id: id, modalities: { output: ['text'] })

      expect(capabilities).to include('tool_search'), id
    end
  end

  it 'does not add tool_search for models Anthropic does not list' do
    %w[claude-opus-4-1 claude-3-5-sonnet claude-opus-4-20250514].each do |id|
      capabilities = described_class.augment(%w[function_calling], model_id: id, modalities: { output: ['text'] })

      expect(capabilities).not_to include('tool_search'), id
    end
  end

  it 'keeps the tool controls it always added' do
    capabilities = described_class.augment(%w[function_calling], model_id: 'claude-opus-4-1',
                                                                 modalities: { output: ['text'] })

    expect(capabilities).to include('tool_choice', 'parallel_tool_calls')
  end

  it 'adds nothing without function calling' do
    capabilities = described_class.augment([], model_id: 'claude-haiku-4-5', modalities: { output: ['text'] })

    expect(capabilities).to be_empty
  end

  it 'emits only capabilities the registry schema accepts, so rake models validates the refreshed registry' do
    capabilities = described_class.augment(%w[function_calling], model_id: 'claude-haiku-4-5',
                                                                 modalities: { output: ['text'] })

    expect(capabilities).to include('tool_search')
    expect(capabilities - RubyLLM::Models::Schema::CAPABILITIES).to be_empty
  end

  it 'does not change the source capability list' do
    original = ['function_calling'].freeze

    described_class.augment(original, model_id: 'claude-haiku-4-5', modalities: { output: ['text'] })

    expect(original).to eq(['function_calling'])
  end
end
