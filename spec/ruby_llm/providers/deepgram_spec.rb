# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Deepgram do
  include_context 'with configured RubyLLM'

  let(:provider) { described_class.new(RubyLLM.config) }

  describe '#api_base' do
    it 'talks to the Deepgram API' do
      expect(provider.api_base).to eq('https://api.deepgram.com')
    end

    it 'honors a configured base' do
      RubyLLM.config.deepgram_api_base = 'https://deepgram.example.com'

      expect(provider.api_base).to eq('https://deepgram.example.com')
    ensure
      RubyLLM.config.deepgram_api_base = nil
    end
  end

  describe '#headers' do
    it 'authenticates with a Token authorization header' do
      RubyLLM.config.deepgram_api_key = 'deepgram-key'

      expect(provider.headers).to eq('Authorization' => 'Token deepgram-key')
    end
  end

  describe '#parse_error' do
    it 'reads the err_msg Deepgram reports' do
      response = instance_double(
        Faraday::Response,
        body: { 'err_code' => 'INVALID_AUTH', 'err_msg' => 'Invalid credentials.', 'request_id' => 'uuid' }
      )

      expect(provider.parse_error(response)).to eq('Invalid credentials.')
    end

    it 'falls back to the generic parser' do
      response = instance_double(Faraday::Response, body: { 'message' => 'Bad request' })

      expect(provider.parse_error(response)).to eq('Bad request')
    end
  end

  describe 'the transcription requests it sends' do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
    let(:listen_response) do
      {
        'metadata' => { 'duration' => 2.5 },
        'results' => { 'channels' => [{ 'alternatives' => [{ 'transcript' => 'Ruby.' }] }] }
      }
    end

    it 'uploads a local file as raw audio bytes under its own content type' do
      stub = stub_request(:post, %r{https://api\.deepgram\.com/v1/listen})
             .with(headers: { 'Content-Type' => 'audio/wav' }, body: File.binread(audio_path))
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram)

      expect(stub).to have_been_requested
    end

    it 'hands a remote url to Deepgram as JSON rather than downloading it' do
      stub = stub_request(:post, %r{https://api\.deepgram\.com/v1/listen})
             .with(headers: { 'Content-Type' => 'application/json' },
                   body: { url: 'https://dpgr.am/spacewalk.wav' })
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe('https://dpgr.am/spacewalk.wav', model: 'nova-3', provider: :deepgram)

      expect(stub).to have_been_requested
    end

    it 'carries the transcription options in the query string' do
      stub = stub_request(:post, 'https://api.deepgram.com/v1/listen')
             .with(query: { model: 'nova-3-general', language: 'en', smart_format: 'true', utterances: 'true',
                            diarize_model: 'latest' })
             .to_return(status: 200, body: listen_response.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram, language: 'en',
                                     speaker_names: ['Speaker'])

      expect(stub).to have_been_requested
    end
  end

  describe 'the speech requests it sends' do
    it 'speaks the text through the query-configured model and encoding' do
      stub = stub_request(:post, 'https://api.deepgram.com/v1/speak')
             .with(query: { model: 'aura-2-zeus-en', encoding: 'linear16', container: 'wav' },
                   body: { text: 'Ship it.' })
             .to_return(status: 200, body: 'audio bytes', headers: { 'Content-Type' => 'audio/wav' })

      speech = RubyLLM.speak('Ship it.', model: 'aura-2-thalia-en', provider: :deepgram, voice: 'zeus',
                                         format: 'wav')

      expect(stub).to have_been_requested
      expect(speech.to_blob).to eq('audio bytes')
    end
  end

  describe 'operations Deepgram has no endpoint for' do
    it 'refuses to chat' do
      chat = RubyLLM.chat(model: 'nova-3', provider: :deepgram)

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::Error, "Deepgram doesn't support chat")
    end

    it 'refuses to embed' do
      expect do
        RubyLLM.embed('Hello', model: 'nova-3', provider: :deepgram)
      end.to raise_error(RubyLLM::Error, "Deepgram doesn't support embeddings")
    end

    it 'refuses to paint' do
      expect do
        RubyLLM.paint('A ruby', model: 'nova-3', provider: :deepgram)
      end.to raise_error(RubyLLM::Error, "Deepgram doesn't support image generation")
    end

    it 'has no chat model to fall back on' do
      expect { RubyLLM.chat(provider: :deepgram) }.to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'refuses to stream a transcription' do
      expect do
        RubyLLM.transcribe('spec/fixtures/ruby.wav', model: 'nova-3', provider: :deepgram) { |chunk| chunk }
      end.to raise_error(RubyLLM::Error, "Deepgram doesn't support streaming transcription")
    end
  end

  describe 'audio', :live do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }

    before do
      if VCR.current_cassette&.recording? && ENV.fetch('DEEPGRAM_API_KEY', nil).nil?
        skip 'Set DEEPGRAM_API_KEY to record the Deepgram cassettes'
      end
    end

    it 'transcribes a local file with nova-3' do
      transcription = RubyLLM.transcribe(audio_path, model: 'nova-3', provider: :deepgram)

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.model).to eq('nova-3-general')
      expect(transcription.duration).to be > 0
      expect(transcription.words).to be_an(Array)
    end

    it 'transcribes audio Deepgram fetches from a url' do
      transcription = RubyLLM.transcribe('https://dpgr.am/spacewalk.wav', model: 'nova-3', provider: :deepgram)

      expect(transcription.text).to be_a(String)
      expect(transcription.segments).to be_an(Array)
    end

    it 'labels words with speakers when speaker names are given' do
      transcription = RubyLLM.transcribe(
        audio_path,
        model: 'nova-3',
        provider: :deepgram,
        language: 'en',
        speaker_names: ['Speaker']
      )

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.words.first).to have_key('speaker')
    end

    it 'speaks text with aura-2' do
      speech = RubyLLM.speak(
        'Ruby is a programming language designed for developer happiness.',
        model: 'aura-2-thalia-en',
        provider: :deepgram
      )

      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq('aura-2-thalia-en')
      expect(speech.voice).to eq('thalia')
      expect(speech.mime_type).to eq('audio/mpeg')
    end

    it 'swaps the voice inside the model id and honors the format' do
      speech = RubyLLM.speak(
        'Save this as a WAV file.',
        model: 'aura-2-thalia-en',
        provider: :deepgram,
        voice: 'zeus',
        format: 'wav'
      )

      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq('aura-2-zeus-en')
      expect(speech.voice).to eq('zeus')
      expect(speech.format).to eq('wav')
    end

    it 'lists the listening and speaking models' do
      models = provider.list_models

      expect(models.map(&:id)).to include('nova-3-general', 'aura-2-thalia-en')
      expect(models.map(&:id)).to eq(models.map(&:id).uniq)
      expect(models.find { |model| model.id == 'nova-3-general' }.capabilities).to eq(['transcription'])
    end
  end
end
