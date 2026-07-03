# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Transcription do
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
