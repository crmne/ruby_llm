# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::RedCandle::Models do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { RubyLLM::Providers::RedCandle.new(config) }

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    require 'candle'
  rescue LoadError
    skip 'Red Candle gem is not installed'
  end

  describe '#models' do
    it 'returns an array of supported models' do
      models = provider.models
      expect(models).to be_an(Array)
      expect(models.size).to eq(3)
      expect(models.first).to be_a(RubyLLM::Model::Info)
    end

    it 'includes the expected model IDs' do
      model_ids = provider.models.map(&:id)
      expect(model_ids).to include('google/gemma-3-4b-it-qat-q4_0-gguf')
      expect(model_ids).to include('TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')
      expect(model_ids).to include('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')
    end
  end

  describe '#model' do
    context 'with a valid model ID' do
      it 'returns the model' do
        model = provider.model('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')
        expect(model).to be_a(RubyLLM::Model::Info)
        expect(model.id).to eq('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')
      end
    end

    context 'with an invalid model ID' do
      it 'raises an error' do
        expect { provider.model('invalid/model') }.to raise_error(
          RubyLLM::Error,
          %r{Model invalid/model not found}
        )
      end
    end
  end

  describe '#model_available?' do
    it 'returns true for supported models' do
      expect(provider.model_available?('google/gemma-3-4b-it-qat-q4_0-gguf')).to be true
      expect(provider.model_available?('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')).to be true
    end

    it 'returns false for unsupported models' do
      expect(provider.model_available?('gpt-4')).to be false
    end
  end

  describe '#model_info' do
    it 'returns model information' do
      info = provider.model_info('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')
      expect(info).to include(
        id: 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF',
        name: 'Mistral 7B Instruct v0.2 (Quantized)',
        context_window: 32_768,
        family: 'mistral',
        supports_chat: true,
        supports_structured: true
      )
    end

    it 'returns nil for unknown models' do
      expect(provider.model_info('unknown')).to be_nil
    end
  end

  describe '#gguf_file_for' do
    it 'returns the GGUF file for Gemma model' do
      expect(provider.gguf_file_for('google/gemma-3-4b-it-qat-q4_0-gguf')).to eq('gemma-3-4b-it-q4_0.gguf')
    end

    it 'returns the GGUF file for Mistral model' do
      model_id = 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF'
      gguf_file = 'mistral-7b-instruct-v0.2.Q4_K_M.gguf'
      expect(provider.gguf_file_for(model_id)).to eq(gguf_file)
    end

    it 'returns nil for unknown models' do
      expect(provider.gguf_file_for('unknown')).to be_nil
    end
  end

  describe '#supports_chat?' do
    it 'returns true for all current models' do
      expect(provider.supports_chat?('google/gemma-3-4b-it-qat-q4_0-gguf')).to be true
      expect(provider.supports_chat?('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')).to be true
      expect(provider.supports_chat?('TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')).to be true
    end
  end

  describe '#supports_structured?' do
    it 'returns true for all current models' do
      expect(provider.supports_structured?('google/gemma-3-4b-it-qat-q4_0-gguf')).to be true
      expect(provider.supports_structured?('TheBloke/Mistral-7B-Instruct-v0.2-GGUF')).to be true
      expect(provider.supports_structured?('TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')).to be true
    end
  end
end
