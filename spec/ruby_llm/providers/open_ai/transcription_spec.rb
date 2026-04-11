# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Transcription do
  describe '.parse_transcription_response' do
    let(:response) { instance_double(Faraday::Response, body: body) }

    context 'when explicit zero-valued usage fields are present' do
      let(:body) do
        {
          'text' => 'Transcript',
          'language' => 'en',
          'duration' => 1.23,
          'segments' => [],
          'usage' => {
            'input_tokens' => 0,
            'prompt_tokens' => 12,
            'output_tokens' => 0,
            'completion_tokens' => 8
          }
        }
      end

      it 'preserves zero-valued token usage fields' do
        transcription = described_class.parse_transcription_response(response, model: 'gpt-4o-transcribe')

        expect(transcription.input_tokens).to eq(0)
        expect(transcription.output_tokens).to eq(0)
      end
    end

    context 'when only fallback token usage fields are present' do
      let(:body) do
        {
          'text' => 'Transcript',
          'language' => 'en',
          'duration' => 1.23,
          'segments' => [],
          'usage' => {
            'prompt_tokens' => 12,
            'completion_tokens' => 8
          }
        }
      end

      it 'falls back to prompt/completion token usage fields' do
        transcription = described_class.parse_transcription_response(response, model: 'gpt-4o-transcribe')

        expect(transcription.input_tokens).to eq(12)
        expect(transcription.output_tokens).to eq(8)
      end
    end
  end
end
