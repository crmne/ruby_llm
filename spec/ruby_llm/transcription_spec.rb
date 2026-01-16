# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription do
  include_context 'with configured RubyLLM'

  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  describe 'basic functionality' do
    TRANSCRIPTION_MODELS.each do |config|
      provider = config[:provider]
      model = config[:model]

      it "#{provider}/#{model} can transcribe audio" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider)

        expect(transcription.text).to be_a(String)
        expect(transcription.text).not_to be_empty
        expect(transcription.model).to eq(model)
      end

      it "#{provider}/#{model} can transcribe with language hint" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider, language: 'en')

        expect(transcription.text).to be_a(String)
        expect(transcription.text).not_to be_empty
        expect(transcription.model).to eq(model)
      end
    end

    it 'validates model existence' do
      expect do
        RubyLLM.transcribe(audio_path, model: 'invalid-transcription-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end
end
