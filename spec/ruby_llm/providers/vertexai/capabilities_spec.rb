# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI::Capabilities do
  it 'includes documented function calling modes for Gemini 2.5 Flash' do
    capabilities = described_class.augment(
      ['function_calling'], model_id: 'gemini-2.5-flash',
                            modalities: { input: %w[text image audio video], output: ['text'] }
    )

    expect(capabilities).to include('tool_choice', 'transcription')
    expect(capabilities).not_to include('parallel_tool_calls')
  end

  it 'does not infer tool controls for another publisher' do
    capabilities = described_class.augment(
      ['function_calling'], model_id: 'meta/llama-4-maverick-17b-128e-instruct-maas',
                            modalities: { input: ['text'], output: ['text'] }
    )

    expect(capabilities).to eq(['function_calling'])
  end

  it 'does not change the source capability list' do
    original = ['function_calling'].freeze

    described_class.augment(original, model_id: 'gemini-2.5-flash', modalities: { input: ['text'], output: ['text'] })

    expect(original).to eq(['function_calling'])
  end
end
