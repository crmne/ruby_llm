# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ElevenLabs::Speech do
  let(:protocol) { Object.new.extend(described_class) }

  describe '#speech_url' do
    it 'defaults to the voice the ElevenLabs quickstart uses' do
      expect(protocol.speech_url).to eq(
        'v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb?output_format=mp3_44100_128'
      )
    end

    it 'puts the requested voice id in the path' do
      expect(protocol.speech_url(voice: 'pNInz6obpgDQGcFmaJgB')).to eq(
        'v1/text-to-speech/pNInz6obpgDQGcFmaJgB?output_format=mp3_44100_128'
      )
    end

    it 'maps the simple format names onto ElevenLabs output formats' do
      expect(protocol.speech_url(format: 'wav')).to end_with('output_format=wav_44100')
      expect(protocol.speech_url(format: 'opus')).to end_with('output_format=opus_48000_128')
      expect(protocol.speech_url(format: 'pcm')).to end_with('output_format=pcm_44100')
    end

    it 'passes an ElevenLabs output format through untouched' do
      expect(protocol.speech_url(format: 'mp3_22050_32')).to end_with('output_format=mp3_22050_32')
    end
  end

  describe '#render_speech_payload' do
    it 'sends the text and the model id' do
      payload = protocol.render_speech_payload('Hello', model: 'eleven_v3', voice: nil, format: nil)

      expect(payload).to eq(text: 'Hello', model_id: 'eleven_v3')
    end

    it 'merges provider options into the body' do
      payload = protocol.render_speech_payload(
        'Hello',
        model: 'eleven_v3',
        voice: nil,
        format: nil,
        provider_options: { voice_settings: { stability: 0.4 }, language_code: 'en' }
      )

      expect(payload).to eq(
        text: 'Hello',
        model_id: 'eleven_v3',
        voice_settings: { stability: 0.4 },
        language_code: 'en'
      )
    end
  end

  describe '#parse_speech_response' do
    it 'keeps the raw audio bytes and reports the default voice and container' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = protocol.parse_speech_response(response, model: 'eleven_v3', voice: nil, format: nil)

      expect(speech.to_blob).to eq('audio bytes')
      expect(speech.model).to eq('eleven_v3')
      expect(speech.voice).to eq('JBFqnCBsd6RMkjVDRZzb')
      expect(speech.format).to eq('mp3')
      expect(speech.mime_type).to eq('audio/mpeg')
    end

    it 'reports the container that was actually requested' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = protocol.parse_speech_response(response, model: 'eleven_v3', voice: 'abc', format: 'wav')

      expect(speech.voice).to eq('abc')
      expect(speech.format).to eq('wav')
      expect(speech.mime_type).to eq('audio/wav')
    end

    it 'reports the container behind an ElevenLabs output format' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = protocol.parse_speech_response(response, model: 'eleven_v3', voice: nil, format: 'pcm_24000')

      expect(speech.format).to eq('pcm')
      expect(speech.mime_type).to eq('audio/pcm')
    end
  end
end
