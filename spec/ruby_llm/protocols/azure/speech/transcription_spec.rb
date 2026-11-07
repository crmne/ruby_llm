# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Azure::Speech::Transcription do
  let(:protocol) { Object.new.extend(described_class) }

  describe '#render_transcription_definition' do
    it 'turns the profanity filter off by default' do
      expect(protocol.render_transcription_definition).to eq(profanityFilterMode: 'None')
    end

    it 'sends one language as a single locale' do
      expect(protocol.render_transcription_definition(language: 'it-IT')[:locales]).to eq(['it-IT'])
    end

    it 'sends several languages as candidates to identify the spoken one from' do
      definition = protocol.render_transcription_definition(language: %w[en-US it-IT])

      expect(definition[:locales]).to eq(%w[en-US it-IT])
    end

    it 'turns on diarization when speaker names are given' do
      expect(protocol.render_transcription_definition(speaker_names: [])[:diarization]).to eq(enabled: true)
    end

    it 'sends the prompt as a phrase list' do
      definition = protocol.render_transcription_definition(prompt: %w[RubyLLM Zeitwerk])

      expect(definition[:phraseList]).to eq(phrases: %w[RubyLLM Zeitwerk])
    end

    it 'lets provider options override the defaults' do
      definition = protocol.render_transcription_definition(provider_options: { profanityFilterMode: 'Masked' })

      expect(definition[:profanityFilterMode]).to eq('Masked')
    end
  end

  describe '#render_transcription_options' do
    it 'accepts word timestamps, which Azure always returns' do
      expect(protocol.render_transcription_options(timestamps: :word)).to eq({})
    end

    it 'rejects other granularities' do
      expect { protocol.render_transcription_options(timestamps: :segment) }.to raise_error(ArgumentError)
    end
  end

  describe '#parse_transcription_response' do
    def response(body)
      Struct.new(:body).new(body)
    end

    it 'reads the transcript, language, duration, and timing' do
      transcription = protocol.parse_transcription_response(response(
                                                              'durationMilliseconds' => 3700,
                                                              'combinedPhrases' => [{ 'text' => 'Ruby rocks.' }],
                                                              'phrases' => [{
                                                                'offsetMilliseconds' => 110,
                                                                'durationMilliseconds' => 1200,
                                                                'text' => 'Ruby rocks.',
                                                                'locale' => 'en-US',
                                                                'speaker' => 1,
                                                                'words' => [{ 'text' => 'Ruby',
                                                                              'offsetMilliseconds' => 110,
                                                                              'durationMilliseconds' => 560 }]
                                                              }]
                                                            ), model: 'fast-transcription')

      expect(transcription).to have_attributes(text: 'Ruby rocks.', model: 'fast-transcription', language: 'en-US',
                                               duration: 3.7)
      expect(transcription.tokens.audio_seconds).to eq(3.7)
      expect(transcription.segments.first).to have_attributes(text: 'Ruby rocks.', speaker: 1, start: 0.11, end: 1.31)
      expect(transcription.words.first).to have_attributes(text: 'Ruby', start: 0.11, end: 0.67)
    end

    it 'returns an empty transcript for silence' do
      transcription = protocol.parse_transcription_response(response(
                                                              'durationMilliseconds' => 2000,
                                                              'combinedPhrases' => [{ 'text' => '' }],
                                                              'phrases' => []
                                                            ), model: 'fast-transcription')

      expect(transcription).to have_attributes(text: '', language: nil, duration: 2.0)
    end
  end
end
