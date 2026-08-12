# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ElevenLabs::Transcription do
  let(:protocol) { Object.new.extend(described_class) }
  let(:file_part) { instance_double(Faraday::Multipart::FilePart) }

  describe '#transcription_url' do
    it 'posts to the speech-to-text endpoint' do
      expect(protocol.transcription_url).to eq('v1/speech-to-text')
    end
  end

  describe '#render_transcription_payload' do
    it 'sends the model id and the file' do
      payload = protocol.render_transcription_payload(file_part, model: 'scribe_v2', language: nil)

      expect(payload).to eq(model_id: 'scribe_v2', file: file_part)
    end

    it 'passes the language hint as a language code' do
      payload = protocol.render_transcription_payload(file_part, model: 'scribe_v2', language: 'en')

      expect(payload[:language_code]).to eq('en')
    end

    it 'turns on diarization and caps the speakers when speaker names are given' do
      payload = protocol.render_transcription_payload(
        file_part, model: 'scribe_v2', language: nil, speaker_names: %w[Alice Bob]
      )

      expect(payload[:diarize]).to be(true)
      expect(payload[:num_speakers]).to eq(2)
    end

    it 'leaves diarization alone without speaker names' do
      payload = protocol.render_transcription_payload(file_part, model: 'scribe_v2', language: nil)

      expect(payload).not_to have_key(:diarize)
      expect(payload).not_to have_key(:num_speakers)
    end

    it 'asks for word or character timestamps through format' do
      payload = protocol.render_transcription_payload(
        file_part, model: 'scribe_v2', language: nil, format: 'character'
      )

      expect(payload[:timestamps_granularity]).to eq('character')
    end

    it 'passes temperature and provider options through' do
      payload = protocol.render_transcription_payload(
        file_part,
        model: 'scribe_v2',
        language: nil,
        temperature: 0.2,
        provider_options: { keyterms: ['RubyLLM'], tag_audio_events: true }
      )

      expect(payload[:temperature]).to eq(0.2)
      expect(payload[:keyterms]).to eq(['RubyLLM'])
      expect(payload[:tag_audio_events]).to be(true)
    end
  end

  describe '#parse_transcription_response' do
    it 'reads the transcript, language, duration, and word timestamps' do
      response = Struct.new(:body).new(
        {
          'language_code' => 'en',
          'language_probability' => 0.98,
          'text' => 'Hello world!',
          'audio_duration_secs' => 10.5,
          'words' => [
            { 'text' => 'Hello', 'start' => 0, 'end' => 0.5, 'type' => 'word', 'speaker_id' => 'speaker_1' }
          ]
        }
      )

      transcription = protocol.parse_transcription_response(response, model: 'scribe_v2')

      expect(transcription.text).to eq('Hello world!')
      expect(transcription.model).to eq('scribe_v2')
      expect(transcription.language).to eq('en')
      expect(transcription.duration).to eq(10.5)
      expect(transcription.words.first).to include('speaker_id' => 'speaker_1', 'type' => 'word')
    end
  end
end
