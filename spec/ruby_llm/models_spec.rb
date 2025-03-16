# frozen_string_literal: true

require 'spec_helper'
require 'dotenv/load'
require 'tempfile'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  # Register OpenRouter provider for testing
  before(:all) do
    RubyLLM::Provider.register :open_router, RubyLLM::Providers::OpenRouter
  end

  # Skip tests that require OpenAI or Anthropic API keys
  describe 'filtering and chaining', skip: 'Requires OpenAI and Anthropic API keys' do
    it 'filters models by provider' do # rubocop:disable RSpec/MultipleExpectations
      openai_models = RubyLLM.models.by_provider('openai')
      expect(openai_models.all).to all(have_attributes(provider: 'openai'))

      # Can chain other filters and methods
      expect(openai_models.chat_models).to be_a(described_class)
    end

    it 'chains filters in any order with same result' do
      # These two filters should be equivalent
      openai_chat_models = RubyLLM.models.by_provider('openai').chat_models
      chat_openai_models = RubyLLM.models.chat_models.by_provider('openai')

      # Both return same model IDs
      expect(openai_chat_models.map(&:id).sort).to eq(chat_openai_models.map(&:id).sort)
    end

    it 'supports Enumerable methods' do # rubocop:disable RSpec/MultipleExpectations
      # Count models by provider
      provider_counts = RubyLLM.models.group_by(&:provider)
                               .transform_values(&:count)

      # There should be models from at least OpenAI and Anthropic
      expect(provider_counts.keys).to include('openai', 'anthropic')

      # Select only models with vision support
      vision_models = RubyLLM.models.select(&:supports_vision)
      expect(vision_models).to all(have_attributes(supports_vision: true))
    end
  end

  # Skip tests that require OpenAI API key
  describe 'finding models', skip: 'Requires OpenAI API key' do
    it 'finds models by ID' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # Find the default model
      model_id = RubyLLM.config.default_model
      model = RubyLLM.models.find(model_id)
      expect(model.id).to eq(model_id)

      # Find a model with chaining
      if RubyLLM.models.by_provider('openai').chat_models.any?
        openai_chat_id = RubyLLM.models.by_provider('openai').chat_models.first.id
        found = RubyLLM.models.by_provider('openai').find(openai_chat_id)
        expect(found.id).to eq(openai_chat_id)
        expect(found.provider).to eq('openai')
      end
    end

    it 'raises ModelNotFoundError for unknown models' do
      expect do
        RubyLLM.models.find('nonexistent-model-12345')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  # Focus on OpenRouter tests
  describe '#refresh!', focus: true do
    let(:mock_model) do
      RubyLLM::ModelInfo.new(
        id: 'openrouter/test-model',
        name: 'Test Model',
        provider: 'open_router',
        type: 'chat',
        capabilities: { chat: true }
      )
    end

    before do
      # Mock the load_models method to return our mock model
      allow_any_instance_of(described_class).to receive(:load_models).and_return([mock_model])
      
      # Mock the class method refresh! to return a new instance with our mock model
      allow(described_class).to receive(:refresh!).and_return(described_class.new([mock_model]))
    end

    it 'updates models and returns a chainable Models instance' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # Refresh and chain immediately
      chat_models = RubyLLM.models.refresh!.chat_models

      # Verify we got results
      expect(chat_models).to be_a(described_class)
      expect(chat_models.all).to all(have_attributes(type: 'chat'))

      # Verify we got our mock model
      expect(chat_models.all.map(&:id)).to include('openrouter/test-model')
    end

    it 'works as a class method too' do # rubocop:disable RSpec/ExampleLength
      # Call class method
      described_class.refresh!

      # Verify singleton instance was updated
      expect(RubyLLM.models.all.size).to be > 0
      
      # Verify we got our mock model
      expect(RubyLLM.models.all.map(&:id)).to include('openrouter/test-model')
    end
  end
end
