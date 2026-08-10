# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Speech do
  describe '.render_speech_payload' do
    it 'passes the voice through without an OpenAI-style default' do
      payload = described_class.render_speech_payload('Hello', model: 'voxtral-mini-tts-latest',
                                                               voice: 'en_paul_neutral', format: nil)

      expect(payload).to eq(model: 'voxtral-mini-tts-latest', input: 'Hello', voice: 'en_paul_neutral')
    end
  end

  describe '.parse_speech_response' do
    it 'decodes base64 audio_data from the JSON body' do
      response = instance_double(Faraday::Response, body: { 'audio_data' => Base64.strict_encode64('audio bytes') })

      speech = described_class.parse_speech_response(response, model: 'voxtral-mini-tts-latest',
                                                               voice: 'en_paul_neutral', format: nil)

      expect(speech.data).to eq('audio bytes')
      expect(speech.format).to eq('mp3')
      expect(speech.voice).to eq('en_paul_neutral')
    end
  end
end
