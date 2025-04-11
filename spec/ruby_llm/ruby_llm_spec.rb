# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  include_context 'with configured RubyLLM'

  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }
  let(:default_model) { 'whisper-1' }

  before do
    allow(described_class.config).to receive(:default_transcription_model).and_return(default_model)
    allow(described_class::Models).to receive(:find).with(default_model)
    allow(described_class::Provider).to receive(:for).with(default_model).and_return(described_class::Providers::OpenAI)
    allow(described_class::Providers::OpenAI).to receive(:transcribe)
  end

  describe '.transcribe' do
    it 'uses the default model from config when no model is specified' do # rubocop:disable RSpec/MultipleExpectations
      described_class.transcribe(audio_path)

      expect(described_class::Provider).to have_received(:for).with(default_model)
      expect(described_class::Providers::OpenAI).to have_received(:transcribe).with(
        audio_path, model: default_model, language: nil
      )
    end

    it 'validates and uses a custom model when specified' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      custom_model = 'whisper-large'
      allow(described_class::Models).to receive(:find).with(custom_model)
      allow(described_class::Provider).to receive(:for).with(custom_model)
                                                       .and_return(described_class::Providers::OpenAI)

      described_class.transcribe(audio_path, model: custom_model)

      expect(described_class::Models).to have_received(:find).with(custom_model)
      expect(described_class::Provider).to have_received(:for).with(custom_model)
      expect(described_class::Providers::OpenAI).to have_received(:transcribe).with(
        audio_path, model: custom_model, language: nil
      )
    end

    it 'passes language parameter to the provider' do
      language = 'en'

      described_class.transcribe(audio_path, language: language)

      expect(described_class::Providers::OpenAI).to have_received(:transcribe).with(
        audio_path, model: default_model, language: language
      )
    end
  end
end
