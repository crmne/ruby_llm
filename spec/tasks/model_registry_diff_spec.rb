# frozen_string_literal: true

require 'spec_helper'
require_relative '../../tasks/support/model_registry_diff'

RSpec.describe ModelRegistryDiff do
  def model(id:, provider:, **attributes)
    RubyLLM::Model.new(id: id, provider: provider, **attributes)
  end

  it 'reports a removed model' do
    existing = model(id: 'retired', provider: 'acme')

    expect(described_class.call([existing], [])).to eq(['acme:retired was removed'])
  end

  it 'reports removed scalar, modality, pricing and capability values' do
    existing = model(
      id: 'gpt-test', provider: 'openai', family: 'gpt', context_window: 1000,
      modalities: { input: %w[text image], output: ['text'] },
      capabilities: %w[function_calling vision],
      pricing: { text_tokens: { standard: { input_per_million: 1.0, output_per_million: 2.0 } } }
    )
    current = model(
      id: 'gpt-test', provider: 'openai',
      modalities: { input: ['text'], output: ['text'] },
      capabilities: ['function_calling'],
      pricing: { text_tokens: { standard: { input_per_million: 1.0 } } }
    )

    expect(described_class.call([existing], [current])).to contain_exactly(
      'openai:gpt-test lost family',
      'openai:gpt-test lost context_window',
      'openai:gpt-test lost modalities.input value image',
      'openai:gpt-test lost pricing.text_tokens.standard.output_per_million',
      'openai:gpt-test lost capability vision'
    )
  end

  it 'reports a changed model type' do
    existing = model(id: 'embed-test', provider: 'acme', modalities: { output: ['embeddings'] })
    current = model(id: 'embed-test', provider: 'acme', modalities: { output: ['text'] })

    expect(described_class.call([existing], [current])).to include(
      'acme:embed-test changed type from embedding to chat'
    )
  end
end
