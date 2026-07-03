# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Speech do
  let(:protocol) { Object.new.extend(described_class) }

  describe '#render_speech_payload' do
    it 'renders a Gemini single-speaker speech payload' do
      payload = protocol.render_speech_payload(
        'Hello',
        model: 'gemini-2.5-flash-preview-tts',
        voice: nil,
        format: nil,
        params: {}
      )

      expect(payload).to eq(
        contents: [
          {
            role: 'user',
            parts: [
              { text: 'Hello' }
            ]
          }
        ],
        generationConfig: {
          responseModalities: ['AUDIO'],
          speechConfig: {
            voiceConfig: {
              prebuiltVoiceConfig: {
                voiceName: 'Kore'
              }
            }
          }
        },
        model: 'gemini-2.5-flash-preview-tts'
      )
    end
  end

  describe '#parse_speech_response' do
    it 'decodes Gemini inline audio data' do
      response = instance_double(
        Faraday::Response,
        body: {
          'candidates' => [
            {
              'content' => {
                'parts' => [
                  {
                    'inlineData' => {
                      'data' => Base64.strict_encode64('pcm bytes')
                    }
                  }
                ]
              }
            }
          ]
        }
      )

      speech = protocol.parse_speech_response(response, model: 'gemini-2.5-flash-preview-tts', voice: nil, format: nil)

      expect(speech.to_blob).to eq('pcm bytes')
      expect(speech.model).to eq('gemini-2.5-flash-preview-tts')
      expect(speech.voice).to eq('Kore')
      expect(speech.format).to eq('pcm')
      expect(speech.mime_type).to eq('audio/pcm')
    end

    it 'raises a clear error for unexpected responses' do
      response = instance_double(Faraday::Response, body: {})

      expect do
        protocol.parse_speech_response(response, model: 'gemini-2.5-flash-preview-tts', voice: nil, format: nil)
      end.to raise_error(RubyLLM::Error, 'Unexpected response format from Gemini speech generation API')
    end
  end
end
