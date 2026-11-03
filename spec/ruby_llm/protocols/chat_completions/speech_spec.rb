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
        provider_options: {}
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
        provider_options: { instructions: 'Speak warmly.', speed: 1.2, stream_format: 'audio' }
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

  describe '#speak' do
    it 'counts the characters sent, which per-character speech models bill' do
      context = RubyLLM.context { |config| config.openai_api_key = 'test' }
      allow(RubyLLM::Accounting::Usage).to receive(:ledger).and_return(nil)
      stub_request(:post, 'https://api.openai.com/v1/audio/speech').to_return(body: 'audio bytes')

      speech = context.speak('Héllo there', model: 'tts-1', provider: :openai, assume_model_exists: true)

      expect(speech.tokens.characters).to eq(11)
    end
  end
end
