# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  it 'finds models by alias name' do # rubocop:disable RSpec/MultipleExpectations
    # Core test - can we find a model using just its alias?
    chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
    expect(chat.model.id).to eq('claude-3-5-sonnet-20241022')
    expect(chat.model.provider).to eq('anthropic')
  end

  it 'still supports exact model IDs' do # rubocop:disable RSpec/MultipleExpectations
    # Backward compatibility check
    chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
    expect(chat.model.id).to eq('claude-3-5-sonnet-20241022')
    expect(chat.model.provider).to eq('anthropic')
  end

  it 'finds models by alias and provider' do # rubocop:disable RSpec/MultipleExpectations
    chat = RubyLLM.chat(model: 'claude-3-5-haiku', provider: :bedrock)
    expect(chat.model.id).to eq('anthropic.claude-3-5-haiku-20241022-v1:0')
    expect(chat.model.provider).to eq('bedrock')
  end

  it 'handles models that are both concrete models and alias keys' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
    # This test specifically tests the gpt-4o case where the ID exists as both a concrete model
    # and an alias key in aliases.json

    # Arrange: Set up mock models and aliases
    allow(RubyLLM::Aliases).to receive(:aliases).and_return(
      'gpt-4o' => { 'openai' => 'gpt-4o-2024-11-20' }
    )

    models = [
      RubyLLM::ModelInfo.new(id: 'gpt-4o', provider: 'openai'),
      RubyLLM::ModelInfo.new(id: 'gpt-4o-2024-11-20', provider: 'openai')
    ]
    # Create a models instance with our test data and mock the singleton
    models_instance = RubyLLM::Models.new
    allow(models_instance).to receive(:all).and_return(models)
    allow(RubyLLM::Models).to receive(:instance).and_return(models_instance)

    # Act & Assert: The model should resolve to the aliased version
    chat = RubyLLM.chat(model: 'gpt-4o')
    expect(chat.model.id).to eq('gpt-4o-2024-11-20')
    expect(chat.model.provider).to eq('openai')
  end
end
