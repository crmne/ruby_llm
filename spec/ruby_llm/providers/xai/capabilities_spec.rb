# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Capabilities do
  it 'includes documented tool controls for Grok 4.3' do
    capabilities = described_class.augment(
      %w[function_calling reasoning structured_output], model_id: 'grok-4.3',
                                                        modalities: { input: %w[text image], output: ['text'] }
    )

    expect(capabilities).to include('tool_choice', 'parallel_tool_calls')
  end

  it 'does not infer tool controls for audio models' do
    capabilities = described_class.augment([], model_id: 'grok-tts', modalities: { output: ['audio'] })

    expect(capabilities).to be_empty
  end

  it 'does not change the source capability list' do
    original = ['function_calling'].freeze

    described_class.augment(original, model_id: 'grok-4.3', modalities: { output: ['text'] })

    expect(original).to eq(['function_calling'])
  end
end
