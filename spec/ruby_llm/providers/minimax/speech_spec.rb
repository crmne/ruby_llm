# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Speech do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.render_speech_payload' do
    it 'maps the complete synchronous request vocabulary' do
      payload = described_class.render_speech_payload(
        'Hello', model: 'speech-2.8-hd', voice: 'English_Graceful_Lady', format: 'wav',
                 provider_options: { language_boost: 'English', subtitle_enable: true,
                                     pronunciation_dict: { tone: ['Ruby/(ru1)(bi3)'] },
                                     voice_modify: { pitch: 1 } }
      )

      expect(payload).to include(model: 'speech-2.8-hd', text: 'Hello', stream: false, output_format: 'hex',
                                 voice_setting: { voice_id: 'English_Graceful_Lady' },
                                 audio_setting: { format: 'wav' }, language_boost: 'English',
                                 subtitle_enable: true, pronunciation_dict: { tone: ['Ruby/(ru1)(bi3)'] },
                                 voice_modify: { pitch: 1 })
    end
  end

  describe '.parse_speech_response' do
    it 'decodes hexadecimal audio and validates the API status' do
      response = instance_double(Faraday::Response,
                                 body: { 'data' => { 'audio' => '617564696f', 'status' => 2 },
                                         'base_resp' => { 'status_code' => 0 } })

      speech = described_class.parse_speech_response(response, model: 'speech-2.8-hd', voice: 'voice', format: 'mp3')

      expect(speech.data).to eq('audio')
      expect(speech.model).to eq('speech-2.8-hd')
    end

    it 'raises on a provider error status' do
      response = instance_double(Faraday::Response, body: { base_resp: { status_code: 1002 } })

      expect do
        described_class.parse_speech_response(response, model: 'speech-2.8-hd', voice: nil, format: nil)
      end.to raise_error(RubyLLM::Error, /1002/)
    end
  end
end
