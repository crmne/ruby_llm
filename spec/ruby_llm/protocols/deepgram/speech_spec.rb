# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Deepgram::Speech do
  let(:protocol) { Object.new.extend(described_class) }

  def query_for(url)
    URI.decode_www_form(URI.parse(url).query).to_h
  end

  describe '#speech_url' do
    it 'posts to the speak endpoint with the model in the query' do
      url = protocol.speech_url(model: 'aura-2-thalia-en')

      expect(url).to start_with('v1/speak?')
      expect(query_for(url)).to include('model' => 'aura-2-thalia-en')
    end

    it 'defaults to mp3, which needs no container' do
      params = query_for(protocol.speech_url(model: 'aura-2-thalia-en'))

      expect(params['encoding']).to eq('mp3')
      expect(params).not_to have_key('container')
    end

    it 'wraps linear16 in a WAV header for wav and leaves it bare for pcm' do
      expect(query_for(protocol.speech_url(model: 'aura-2-thalia-en', format: 'wav')))
        .to include('encoding' => 'linear16', 'container' => 'wav')
      expect(query_for(protocol.speech_url(model: 'aura-2-thalia-en', format: 'pcm')))
        .to include('encoding' => 'linear16', 'container' => 'none')
    end

    it 'passes a Deepgram encoding name through untouched' do
      expect(query_for(protocol.speech_url(model: 'aura-2-thalia-en', format: 'linear16')))
        .to include('encoding' => 'linear16')
    end

    it 'takes provider options as query parameters' do
      params = query_for(protocol.speech_url(model: 'aura-2-thalia-en', provider_options: { sample_rate: 48_000 }))

      expect(params['sample_rate']).to eq('48000')
    end
  end

  describe '#speech_model_for' do
    it 'keeps the model as it stands when no voice was asked for' do
      expect(protocol.speech_model_for('aura-2-thalia-en', nil)).to eq('aura-2-thalia-en')
    end

    it 'swaps the voice segment of the model id' do
      expect(protocol.speech_model_for('aura-2-thalia-en', 'zeus')).to eq('aura-2-zeus-en')
      expect(protocol.speech_model_for('aura-asteria-en', 'orion')).to eq('aura-orion-en')
    end

    it 'takes a voice that already names a whole model' do
      expect(protocol.speech_model_for('aura-2-thalia-en', 'aura-2-celeste-es')).to eq('aura-2-celeste-es')
    end
  end

  describe '#voice_for' do
    it 'reads the voice out of the model id' do
      expect(protocol.voice_for('aura-2-thalia-en')).to eq('thalia')
      expect(protocol.voice_for('aura-asteria-en')).to eq('asteria')
    end

    it 'has no voice to report for a model id without one' do
      expect(protocol.voice_for('nova-3')).to be_nil
    end
  end

  describe '#render_speech_payload' do
    it 'sends the text alone, since Deepgram takes its options in the query' do
      payload = protocol.render_speech_payload('Hello', model: 'aura-2-thalia-en', voice: nil, format: nil)

      expect(payload).to eq(text: 'Hello')
    end
  end

  describe '#parse_speech_response' do
    it 'keeps the raw audio bytes and reports the default container' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = protocol.parse_speech_response(response, model: 'aura-2-thalia-en', voice: 'thalia', format: nil)

      expect(speech.to_blob).to eq('audio bytes')
      expect(speech.model).to eq('aura-2-thalia-en')
      expect(speech.voice).to eq('thalia')
      expect(speech.format).to eq('mp3')
      expect(speech.mime_type).to eq('audio/mpeg')
    end

    it 'reports the container that was actually requested' do
      response = instance_double(Faraday::Response, body: 'audio bytes')

      speech = protocol.parse_speech_response(response, model: 'aura-2-zeus-en', voice: 'zeus', format: 'wav')

      expect(speech.format).to eq('wav')
      expect(speech.mime_type).to eq('audio/wav')
    end
  end
end
