# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Speech, :live do
  describe 'basic functionality' do
    each_model(SPEECH_MODELS) do |provider, model, model_info|
      it "#{provider}/#{model} can speak" do
        speech = RubyLLM.speak('Ruby is a programming language designed for developer happiness.',
                               model: model, provider: provider, voice: model_info[:voice])

        expect(speech.data).to be_a(String)
        expect(speech.data.bytesize).to be > 1000
        expect(speech.model).to eq(model)
        expect(speech.mime_type).to start_with('audio/')
      end
    end
  end

  describe '.speak' do
    it 'uses the configured default speech model' do
      model = instance_double(RubyLLM::Model, id: 'gpt-4o-mini-tts-2025-12-15', provider: 'openai')
      provider = instance_double(RubyLLM::Provider, slug: 'openai')
      provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
      speech = described_class.new(
        data: 'audio bytes', model: 'gpt-4o-mini-tts-2025-12-15', voice: 'alloy', format: 'mp3'
      )
      allow(provider).to receive_messages(speak: speech, class: provider_class)
      allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

      result = RubyLLM.speak('Hello')

      expect(result).to eq(speech)
      expect(RubyLLM::Models).to have_received(:resolve).with(
        'gpt-4o-mini-tts-2025-12-15',
        provider: nil,
        assume_model_exists: false,
        config: RubyLLM.config
      )
      expect(provider).to have_received(:speak).with(
        'Hello',
        model: model,
        voice: nil,
        format: nil,
        provider_options: {}
      )
    end

    it 'works from a context with its own default speech model' do
      context = RubyLLM.context do |config|
        config.default_speech_model = model_for(:openai, :alternate_speech)
      end
      model = instance_double(RubyLLM::Model, id: model_for(:openai, :alternate_speech), provider: 'openai')
      provider = instance_double(RubyLLM::Provider, slug: 'openai')
      provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
      speech = described_class.new(data: 'audio bytes', model: model_for(:openai, :alternate_speech), voice: 'alloy',
                                   format: 'mp3')
      allow(provider).to receive_messages(speak: speech, class: provider_class)
      allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

      result = context.speak('Hello')

      expect(result.model).to eq(model_for(:openai, :alternate_speech))
      expect(RubyLLM::Models).to have_received(:resolve).with(
        model_for(:openai, :alternate_speech),
        provider: nil,
        assume_model_exists: false,
        config: context.config
      )
    end

    it 'rejects unknown keyword arguments' do
      expect do
        RubyLLM.speak('Hello', unsupported: true)
      end.to raise_error(ArgumentError, /unknown keyword/)
    end
  end

  describe '#save' do
    it 'writes the audio bytes' do
      speech = described_class.new(data: 'audio bytes', model: model_for(:openai, :speech))
      file = Tempfile.new('speech')

      begin
        expect(speech.save(file.path)).to eq(file.path)
        expect(File.binread(file.path)).to eq('audio bytes')
      ensure
        file.close
        file.unlink
      end
    end
  end

  describe '#mime_type' do
    it 'uses the format when no explicit MIME type is provided' do
      speech = described_class.new(data: 'audio bytes', model: model_for(:openai, :speech), format: 'wav')

      expect(speech.mime_type).to eq('audio/wav')
    end
  end
end
