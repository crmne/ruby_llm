# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::ElevenLabs do
  include_context 'with configured RubyLLM'

  let(:provider) { described_class.new(RubyLLM.config) }

  describe '#api_base' do
    it 'talks to the ElevenLabs API' do
      expect(provider.api_base).to eq('https://api.elevenlabs.io')
    end

    it 'honors a configured base' do
      RubyLLM.config.elevenlabs_api_base = 'https://api.eu.residency.elevenlabs.io'

      expect(provider.api_base).to eq('https://api.eu.residency.elevenlabs.io')
    ensure
      RubyLLM.config.elevenlabs_api_base = nil
    end
  end

  describe '#headers' do
    it 'authenticates with the xi-api-key header' do
      RubyLLM.config.elevenlabs_api_key = 'elevenlabs-key'

      expect(provider.headers).to eq('xi-api-key' => 'elevenlabs-key')
    end
  end

  describe 'operations ElevenLabs has no endpoint for' do
    it 'refuses to chat' do
      chat = RubyLLM.chat(model: 'eleven_v3', provider: :elevenlabs)

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::Error, "ElevenLabs doesn't support chat")
    end

    it 'refuses to embed' do
      expect do
        RubyLLM.embed('Hello', model: 'eleven_v3', provider: :elevenlabs)
      end.to raise_error(RubyLLM::Error, "ElevenLabs doesn't support embeddings")
    end

    it 'refuses to paint' do
      expect do
        RubyLLM.paint('A ruby', model: 'eleven_v3', provider: :elevenlabs)
      end.to raise_error(RubyLLM::Error, "ElevenLabs doesn't support image generation")
    end

    it 'has no chat model to fall back on' do
      expect { RubyLLM.chat(provider: :elevenlabs) }.to raise_error(RubyLLM::ModelNotFoundError)
    end
  end

  describe 'audio', :live do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }

    before { skip_without_cassette_or_key('ELEVENLABS_API_KEY') }

    it 'speaks text with eleven_v3' do
      speech = RubyLLM.speak(
        'Ruby is a programming language designed for developer happiness.',
        model: 'eleven_v3',
        provider: :elevenlabs
      )

      expect(speech.data.bytesize).to be > 1000
      expect(speech.model).to eq('eleven_v3')
      expect(speech.voice).to eq(RubyLLM::Protocols::ElevenLabs::Speech::DEFAULT_VOICE)
      expect(speech.mime_type).to eq('audio/mpeg')
    end

    it 'speaks in a requested voice and format' do
      speech = begin
        RubyLLM.speak(
          'Save this as a WAV file.',
          model: 'eleven_flash_v2_5',
          provider: :elevenlabs,
          voice: '21m00Tcm4TlvDq8ikWAM',
          format: 'wav'
        )
      rescue RubyLLM::ForbiddenError => e
        skip "ElevenLabs rejected the wav output format for this account: #{e.message}"
      end

      expect(speech.data.bytesize).to be > 1000
      expect(speech.voice).to eq('21m00Tcm4TlvDq8ikWAM')
      expect(speech.format).to eq('wav')
    end

    it 'transcribes audio with scribe_v2' do
      transcription = RubyLLM.transcribe(audio_path, model: 'scribe_v2', provider: :elevenlabs)

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.model).to eq('scribe_v2')
      expect(transcription.language).to eq('eng')
    end

    it 'labels words with speakers when speaker names are given' do
      transcription = RubyLLM.transcribe(
        audio_path,
        model: 'scribe_v2',
        provider: :elevenlabs,
        language: 'en',
        speaker_names: ['Speaker']
      )

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.words).to be_an(Array)
      expect(transcription.words.first).to have_key('speaker_id')
    end

    it 'lists the speech models' do
      models = provider.list_models

      expect(models.map(&:id)).to include('eleven_v3', 'scribe_v2')
      expect(models.find { |model| model.id == 'scribe_v2' }.capabilities).to eq(['transcription'])
    end
  end
end
