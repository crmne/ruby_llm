# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Speech do
  include_context 'with configured RubyLLM'

  describe '.speak' do
    it 'uses the configured default speech model' do
      model = instance_double(RubyLLM::Model::Info, id: 'gpt-4o-mini-tts', provider: 'openai')
      provider = instance_double(RubyLLM::Provider, slug: 'openai')
      provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
      speech = described_class.new(data: 'audio bytes', model: 'gpt-4o-mini-tts', voice: 'alloy', format: 'mp3')
      allow(provider).to receive_messages(speak: speech, class: provider_class)
      allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

      result = RubyLLM.speak('Hello')

      expect(result).to eq(speech)
      expect(RubyLLM::Models).to have_received(:resolve).with(
        'gpt-4o-mini-tts',
        provider: nil,
        assume_exists: false,
        config: RubyLLM.config
      )
      expect(provider).to have_received(:speak).with(
        'Hello',
        model: 'gpt-4o-mini-tts',
        voice: nil,
        format: nil,
        params: {}
      )
    end

    it 'works from a context with its own default speech model' do
      context = RubyLLM.context do |config|
        config.default_speech_model = 'tts-1'
      end
      model = instance_double(RubyLLM::Model::Info, id: 'tts-1', provider: 'openai')
      provider = instance_double(RubyLLM::Provider, slug: 'openai')
      provider_class = class_double(RubyLLM::Provider, display_name: 'OpenAI')
      speech = described_class.new(data: 'audio bytes', model: 'tts-1', voice: 'alloy', format: 'mp3')
      allow(provider).to receive_messages(speak: speech, class: provider_class)
      allow(RubyLLM::Models).to receive(:resolve).and_return([model, provider])

      result = context.speak('Hello')

      expect(result.model).to eq('tts-1')
      expect(RubyLLM::Models).to have_received(:resolve).with(
        'tts-1',
        provider: nil,
        assume_exists: false,
        config: context.config
      )
    end
  end

  describe '#save' do
    it 'writes the audio bytes' do
      speech = described_class.new(data: 'audio bytes', model: 'gpt-4o-mini-tts')
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
      speech = described_class.new(data: 'audio bytes', model: 'gpt-4o-mini-tts', format: 'wav')

      expect(speech.mime_type).to eq('audio/wav')
    end
  end
end
