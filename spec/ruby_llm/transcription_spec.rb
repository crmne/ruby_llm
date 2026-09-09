# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Transcription, :live do
  let(:audio_path) { File.expand_path('../fixtures/ruby.wav', __dir__) }

  describe 'basic functionality' do
    each_model(TRANSCRIPTION_MODELS) do |provider, model|
      it "#{provider}/#{model} can transcribe audio" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider)

        expect(transcription.text).to match(/ruby/i)
        expect(transcription.model).to eq(model)
      end

      it "#{provider}/#{model} can transcribe with language hint" do
        transcription = RubyLLM.transcribe(audio_path, model: model, provider: provider, language: 'en')

        expect(transcription.text).to match(/ruby/i)
        expect(transcription.model).to eq(model)
      end
    end

    it "xai/#{model_for(:xai, :transcription)} labels words with speakers when speaker names are given" do
      transcription = RubyLLM.transcribe(audio_path, model: model_for(:xai, :transcription), provider: :xai,
                                                     speaker_names: ['Speaker'])

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.words).to be_an(Array)
      expect(transcription.words.first).to have_key('speaker')
    end

    it "mistral/#{model_for(:mistral, :transcription)} labels segments with speakers when speaker names are given" do
      transcription = RubyLLM.transcribe(audio_path, model: model_for(:mistral, :transcription), provider: :mistral,
                                                     speaker_names: ['Speaker'])

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments).to be_an(Array)
      expect(transcription.segments.first).to have_key('speaker_id')
    end

    it "openai/#{model_for(:openai, :streaming_transcription)} " \
       'streams text deltas and returns the final transcription' do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:openai, :streaming_transcription),
                                                     provider: :openai) do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::TranscriptionChunk)
      expect(chunks.filter_map(&:delta).join).to match(/ruby/i)
      expect(chunks.last).to be_done
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.model).to eq(model_for(:openai, :streaming_transcription))
    end

    it "openai/#{model_for(:openai, :transcription)} streams segments labelled with speakers" do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:openai, :transcription),
                                                     provider: :openai) do |chunk|
        chunks << chunk
      end

      segments = chunks.select(&:segment?)
      expect(segments).not_to be_empty
      expect(segments.first.segment).to have_key('speaker')
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments).to eq(segments.map(&:segment))
    end

    it 'streams Mistral transcriptions with speaker segments and usage' do
      chunks = []

      transcription = RubyLLM.transcribe(audio_path, model: model_for(:mistral, :transcription),
                                                     provider: :mistral, speaker_names: ['Speaker']) do |chunk|
        chunks << chunk
      end

      expect(chunks.last).to be_done
      expect(transcription.text).to match(/ruby/i)
      expect(transcription.segments.first).to have_key('speaker_id')
      expect(transcription.tokens.input).to be_positive
      expect(transcription.duration).to be_positive
    end

    it 'raises for providers that do not stream transcriptions' do
      expect do
        RubyLLM.transcribe(audio_path, model: model_for(:gemini), provider: :gemini) { |chunk| chunk }
      end.to raise_error(RubyLLM::Error, /doesn't support streaming transcription/)
    end

    it 'validates model existence' do
      expect do
        RubyLLM.transcribe(audio_path, model: 'invalid-transcription-model')
      end.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'rejects unknown keyword arguments' do
      expect do
        RubyLLM.transcribe(audio_path, unsupported: true)
      end.to raise_error(ArgumentError, /unknown keyword/)
    end
  end
end
