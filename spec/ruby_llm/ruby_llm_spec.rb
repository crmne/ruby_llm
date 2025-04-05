# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  include_context 'with configured RubyLLM'

  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  describe '.transcribe' do
    it 'can transcribe audio with default model', vcr: {
      cassette_name: 'transcription_default_model_transcribes_audio'
    } do
      transcription = described_class.transcribe(audio_path)

      expect(transcription).to be_a(String)
    end

    it 'returns non-empty output with default model', vcr: {
      cassette_name: 'transcription_default_model_returns_content'
    } do
      transcription = described_class.transcribe(audio_path)

      expect(transcription).not_to be_empty
    end

    it 'includes ruby in the default model transcription', vcr: {
      cassette_name: 'transcription_default_model_includes_ruby'
    } do
      transcription = described_class.transcribe(audio_path)

      expect(transcription.downcase).to include('ruby')
    end

    it 'accepts a specific model', vcr: { cassette_name: 'transcription_specific_model_gpt4o_audio_preview' } do
      transcription = described_class.transcribe(audio_path, model: 'gpt-4o-audio-preview')

      expect(transcription).to be_a(String)
    end

    it 'produces non-empty output with a specific model',
       vcr: { cassette_name: 'transcription_specific_model_output_check' } do
      transcription = described_class.transcribe(audio_path, model: 'gpt-4o-audio-preview')

      expect(transcription).not_to be_empty
    end

    it 'accepts a language hint', vcr: { cassette_name: 'transcription_with_language_hint_english' } do
      transcription = described_class.transcribe(audio_path, language: 'English')

      expect(transcription).to be_a(String)
    end

    it 'produces non-empty output with a language hint',
       vcr: { cassette_name: 'transcription_with_language_hint_output_check' } do
      transcription = described_class.transcribe(audio_path, language: 'English')

      expect(transcription).not_to be_empty
    end
  end
end
