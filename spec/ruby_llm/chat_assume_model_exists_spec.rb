# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#assume_model_exists' do
    let(:real_model) { 'gpt-4.1-nano' }
    let(:custom_model) { 'my-custom-model' }
    let(:provider) { 'openai' }
    # Keep a reference to the original models for cleanup
    let!(:original_models) { RubyLLM::Models.instance.all.dup }

    # Clean up the model registry after each test
    after do
      RubyLLM::Models.instance.instance_variable_set(:@models, original_models)
    end

    it 'requires provider when assuming model exists' do
      expect do
        described_class.new(model: custom_model, assume_model_exists: true)
      end.to raise_error(ArgumentError, /Provider must be specified/)
    end

    it 'skips registry validation when assuming model exists' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      expect(RubyLLM::Models).not_to receive(:find) # rubocop:disable RSpec/MessageSpies

      chat = described_class.new(
        model: custom_model,
        provider: provider,
        assume_model_exists: true
      )

      expect(chat.model.id).to eq(custom_model)
      expect(chat.model.provider.slug).to eq(provider)
    end

    it 'works with RubyLLM.chat convenience method' do # rubocop:disable RSpec/ExampleLength
      chat = RubyLLM.chat(
        model: custom_model,
        provider: provider,
        assume_model_exists: true
      )

      expect(chat.model.id).to eq(custom_model)
    end

    it 'works with models not in registry but available in API' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
      # Simulate model missing from registry
      filtered_models = original_models.reject { |m| m.id == real_model }
      RubyLLM::Models.instance.instance_variable_set(:@models, filtered_models)

      # Should raise error when not assuming existence
      expect do
        RubyLLM.chat(model: real_model)
      end.to raise_error(RubyLLM::ModelNotFoundError)

      # Should work when assuming existence
      chat = RubyLLM.chat(
        model: real_model,
        provider: provider,
        assume_model_exists: true
      )

      # Should be able to actually use the model (relies on VCR)
      response = chat.ask('What is 2 + 2?')
      expect(response.content).to include('4')
    end

    it 'works with with_model method' do # rubocop:disable RSpec/MultipleExpectations
      chat = RubyLLM.chat

      chat.with_model(custom_model, provider: provider, assume_exists: true)

      expect(chat.model.id).to eq(custom_model)
      expect(chat.model.provider.slug).to eq(provider)
    end
  end
end
