# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure do
  let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
  let(:model) { described_class::FAST_TRANSCRIPTION_MODEL }

  describe 'fast transcription', live: false do
    let(:context) do
      RubyLLM.context do |config|
        config.azure_api_base = 'https://contoso.openai.azure.com/openai/v1'
        config.azure_api_key = 'test-key'
      end
    end
    let(:url) { 'https://contoso.openai.azure.com/speechtotext/transcriptions:transcribe?api-version=2025-10-15' }

    it 'posts to Azure AI Speech on the resource host with the resource key' do
      request = stub_request(:post, url)
                .with(headers: { 'Ocp-Apim-Subscription-Key' => 'test-key' }) do |req|
                  req.body.include?('name="audio"') && req.body.include?('"locales":["en-US","it-IT"]')
                end
                .to_return_json(body: { durationMilliseconds: 3700, combinedPhrases: [{ text: 'Ruby.' }],
                                        phrases: [{ text: 'Ruby.', locale: 'en-US' }] })

      transcription = context.transcribe(audio_path, model:, provider: :azure, language: %w[en-US it-IT])

      expect(request).to have_been_requested.once
      expect(transcription).to have_attributes(text: 'Ruby.', language: 'en-US', duration: 3.7)
    end

    it 'routes fast transcription to Azure AI Speech even when another protocol is configured' do
      configured = RubyLLM.context do |config|
        config.azure_api_base = 'https://contoso.services.ai.azure.com'
        config.azure_api_key = 'test-key'
        config.azure_protocol = :responses
      end
      provider = described_class.new(configured.config)

      expect(provider.resolve_protocol(nil, RubyLLM::Model.default(model, 'azure'), operation: :transcribe))
        .to eq(RubyLLM::Protocols::Azure::Speech)
    end

    {
      'https://solco-dictation.cognitiveservices.azure.com/' => 'https://solco-dictation.cognitiveservices.azure.com',
      'https://acme.services.ai.azure.com/api/projects/notes' => 'https://acme.services.ai.azure.com',
      'https://swedencentral.api.cognitive.microsoft.com' => 'https://swedencentral.api.cognitive.microsoft.com',
      'https://speech.internal.example:8443/openai/v1' => 'https://speech.internal.example:8443'
    }.each do |base, host|
      it "calls Azure AI Speech on #{host} for #{base}" do
        regional = RubyLLM.context do |config|
          config.azure_api_base = base
          config.azure_api_key = 'test-key'
        end

        expect(described_class.new(regional.config).azure_speech_transcription_url)
          .to eq("#{host}/speechtotext/transcriptions:transcribe?api-version=2025-10-15")
      end
    end

    it 'leaves the resource key out when an Entra ID token signs the request' do
      token_context = RubyLLM.context do |config|
        config.azure_api_base = 'https://contoso.services.ai.azure.com'
        config.azure_api_key = nil
        config.azure_ai_auth_token = 'token'
      end

      expect(described_class.new(token_context.config).azure_speech_headers).to eq({})
    end

    it 'rejects options the endpoint cannot carry' do
      expect { context.transcribe(audio_path, model:, provider: :azure, format: 'srt') }
        .to raise_error(ArgumentError, /format/)
    end

    it 'lists fast transcription in the catalog' do
      provider = described_class.new(context.config)
      models = RubyLLM::Providers::Azure::ChatCompletions.new(provider)
                                                         .parse_list_models_response(
                                                           Struct.new(:body).new({ 'data' => [] }), 'azure'
                                                         )

      expect(models.map(&:id)).to eq([model])
      expect(models.first.capabilities).to include('transcription')
    end
  end

  describe 'fast transcription', :live do
    it 'transcribes audio and reports the billed seconds' do
      transcription = RubyLLM.transcribe(audio_path, model:, provider: :azure, language: 'en-US')

      expect(transcription.text).to match(/ruby/i)
      expect(transcription).to have_attributes(model:, language: 'en-US')
      expect(transcription.tokens.audio_seconds).to eq(4.0)
    end

    it 'identifies the language from candidates' do
      transcription = RubyLLM.transcribe(audio_path, model:, provider: :azure, language: %w[it-IT en-US])

      expect(transcription.text).to match(/ruby/i)
      expect(transcription.language).to eq('en-US')
    end

    it 'labels speakers when asked' do
      transcription = RubyLLM.transcribe(audio_path, model:, provider: :azure, speaker_names: [])

      expect(transcription.segments.first.speaker).not_to be_nil
      expect(transcription.words.first.speaker).to eq(transcription.segments.first.speaker)
    end
  end
end
