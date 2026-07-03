# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Speech do
  describe '.render_speech_payload' do
    it 'renders a minimal OpenAI speech payload' do
      payload = described_class.render_speech_payload(
        'Hello',
        model: 'gpt-4o-mini-tts',
        voice: nil,
        format: nil,
        params: {}
      )

      expect(payload).to eq(
        model: 'gpt-4o-mini-tts',
        input: 'Hello',
        voice: 'alloy'
      )
    end

    it 'renders OpenAI speech options' do
      payload = described_class.render_speech_payload(
        'Hello',
        model: 'gpt-4o-mini-tts',
        voice: 'nova',
        format: 'wav',
        params: { stream_format: 'audio' },
        instructions: 'Speak warmly.',
        speed: 1.2
      )

      expect(payload).to eq(
        model: 'gpt-4o-mini-tts',
        input: 'Hello',
        voice: 'nova',
        response_format: 'wav',
        instructions: 'Speak warmly.',
        speed: 1.2,
        stream_format: 'audio'
      )
    end
  end

  describe '.parse_speech_response' do
    it 'wraps binary audio in a Speech object' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = described_class.parse_speech_response(response, model: 'gpt-4o-mini-tts', voice: nil, format: nil)

      expect(speech).to be_a(RubyLLM::Speech)
      expect(speech.to_blob).to eq('audio bytes')
      expect(speech.model).to eq('gpt-4o-mini-tts')
      expect(speech.voice).to eq('alloy')
      expect(speech.format).to eq('mp3')
      expect(speech.mime_type).to eq('audio/mpeg')
    end
  end
end
