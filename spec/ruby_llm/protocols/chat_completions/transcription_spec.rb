# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Transcription do
  describe '.render_transcription_payload' do
    it 'defaults diarize models to diarized_json with auto chunking' do
      payload = described_class.render_transcription_payload(
        'file-part', model: 'gpt-4o-transcribe-diarize', language: nil
      )

      expect(payload).to eq(
        model: 'gpt-4o-transcribe-diarize',
        file: 'file-part',
        chunking_strategy: 'auto',
        response_format: 'diarized_json'
      )
    end

    it 'sets no defaults for other models' do
      payload = described_class.render_transcription_payload('file-part', model: 'whisper-1', language: 'en')

      expect(payload).to eq(model: 'whisper-1', file: 'file-part', language: 'en')
    end

    it 'maps format to response_format' do
      payload = described_class.render_transcription_payload(
        'file-part', model: 'whisper-1', language: nil, format: 'verbose_json'
      )

      expect(payload[:response_format]).to eq('verbose_json')
    end

    it 'maps speaker names and references to the known speaker fields' do
      reference = File.expand_path('../../../fixtures/ruby.wav', __dir__)
      payload = described_class.render_transcription_payload(
        'file-part', model: 'gpt-4o-transcribe-diarize', language: nil,
                     speaker_names: ['Alice'], speaker_references: [reference]
      )

      expect(payload[:known_speaker_names]).to eq(['Alice'])
      expect(payload[:known_speaker_references].length).to eq(1)
    end

    it 'merges provider options over rendered defaults' do
      payload = described_class.render_transcription_payload(
        'file-part', model: 'gpt-4o-transcribe-diarize', language: nil,
                     provider_options: { chunking_strategy: { type: 'server_vad' }, response_format: 'json' }
      )

      expect(payload[:chunking_strategy]).to eq(type: 'server_vad')
      expect(payload[:response_format]).to eq('json')
    end
  end

  describe '.parse_transcription_response' do
    it 'preserves word-level timestamp data from verbose transcription responses' do
      words = [
        { 'word' => 'Hello', 'start' => 0.0, 'end' => 0.5 },
        { 'word' => 'world', 'start' => 0.6, 'end' => 1.0 }
      ]
      response_body = {
        'text' => 'Hello world',
        'language' => 'english',
        'duration' => 1.0,
        'segments' => [
          { 'id' => 0, 'text' => 'Hello world', 'start' => 0.0, 'end' => 1.0 }
        ],
        'words' => words,
        'usage' => {
          'input_tokens' => 12,
          'output_tokens' => 3
        }
      }
      response = instance_double(Faraday::Response, body: response_body)

      transcription = described_class.parse_transcription_response(response, model: 'whisper-1')

      expect(transcription.text).to eq('Hello world')
      expect(transcription.words).to eq(words)
      expect(transcription.segments).to eq(response_body['segments'])
      expect(transcription.input_tokens).to eq(12)
      expect(transcription.output_tokens).to eq(3)
    end
  end
end
