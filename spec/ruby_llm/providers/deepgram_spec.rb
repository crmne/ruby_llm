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
  end

  describe 'models', :live do
    before do
      if VCR.current_cassette&.recording? && ENV.fetch('DEEPGRAM_API_KEY', nil).nil?
        skip 'Set DEEPGRAM_API_KEY to record the Deepgram cassettes'
      end
    end

    it 'lists the listening and speaking models' do
      models = provider.list_models

      expect(models.map(&:id)).to include('nova-3', 'aura-2-thalia-en')
      expect(models.find { |model| model.id == 'nova-3' }.capabilities).to eq(['transcription'])
    end
  end
end
