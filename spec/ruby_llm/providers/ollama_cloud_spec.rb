# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OllamaCloud do
  subject(:provider) { described_class.new(config) }

  let(:config) do
    RubyLLM::Configuration.new.tap do |provider_config|
      provider_config.ollama_cloud_api_key = 'test-key'
    end
  end

  it 'speaks the Ollama dialect of Chat Completions' do
    expect(described_class.protocols).to include(chat_completions: described_class::ChatCompletions)
    expect(described_class::ChatCompletions.superclass).to eq(RubyLLM::Providers::Ollama::ChatCompletions)
  end

  it 'declares provider configuration' do
    expect(described_class.configuration_options).to eq(%i[ollama_cloud_api_key ollama_cloud_api_base])
    expect(described_class.configuration_requirements).to eq(%i[ollama_cloud_api_key])
  end

  it 'defaults to the ollama.com endpoint and sends a bearer token' do
    expect(provider.api_base).to eq('https://ollama.com/v1')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'talks to a configured endpoint instead of the default' do
    config.ollama_cloud_api_base = 'https://ollama-proxy.example.com/v1'

    expect(provider.api_base).to eq('https://ollama-proxy.example.com/v1')
  end

  it 'is a remote provider, unlike local Ollama' do
    expect(described_class).not_to be_local
    expect(RubyLLM::Provider.providers).to include(ollama_cloud: described_class)
    expect(described_class).to be_remote
  end

  it 'requires an API key' do
    expect(described_class.configured?(RubyLLM::Configuration.new)).to be(false)
    expect(described_class.configured?(config)).to be(true)
  end

  it 'allows model ids missing from the registry' do
    expect(described_class.assume_models_exist?).to be(true)
  end

  describe 'model listing' do
    let(:response) do
      instance_double(
        Faraday::Response,
        body: {
          'data' => [
            { 'id' => 'gpt-oss:120b', 'created' => 1_754_352_000, 'owned_by' => 'ollama' }
          ]
        }
      )
    end

    it 'reads the cloud catalog without the local -cloud suffix' do
      models = described_class::ChatCompletions.allocate.parse_list_models_response(response, 'ollama_cloud')

      expect(models.map(&:id)).to eq(['gpt-oss:120b'])
      expect(models.first.provider).to eq('ollama_cloud')
    end

    it 'reports no structured output, which Ollama Cloud does not support' do
      models = described_class::ChatCompletions.allocate.parse_list_models_response(
        response, 'ollama_cloud', details: { 'gpt-oss:120b' => %w[completion tools thinking] }
      )

      expect(models.first.capabilities).to eq(%w[streaming function_calling reasoning])
      expect(models.first.supports?(:structured_output)).to be(false)
    end

    it 'leaves vision to the models that /api/show says have it' do
      models = described_class::ChatCompletions.allocate.parse_list_models_response(
        response, 'ollama_cloud', details: { 'gpt-oss:120b' => %w[completion tools thinking] }
      )

      expect(models.first.supports?(:vision)).to be(false)
      expect(models.first.modalities.input).to eq(%w[text])
    end
  end

  describe 'operations ollama.com does not serve' do
    let(:audio_path) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
    let!(:route) do
      stub_request(:post, %r{\Ahttps://ollama\.com/v1/}).to_return(
        status: 404, headers: { 'Content-Type' => 'application/json' }, body: { error: 'path not found' }.to_json
      )
    end
    let!(:remote_input) { stub_request(:get, %r{\Ahttps://assets\.example\.com/}).to_return(status: 500) }
    let(:model) { { model: 'gemma4:31b', provider: :ollama_cloud, assume_model_exists: true } }

    before do
      RubyLLM.configure { |config| config.ollama_cloud_api_key = 'test' }
    end

    def expect_unsupported(label, &)
      expect(&).to raise_error(RubyLLM::Error, "OllamaCloud doesn't support #{label}")
      expect(route).not_to have_been_requested
      expect(remote_input).not_to have_been_requested
    end

    it 'raises for embeddings without a request' do
      expect_unsupported('embeddings') { RubyLLM.embed('Hello', **model) }
    end

    it 'raises for speech without a request' do
      expect_unsupported('speech generation') { RubyLLM.speak('Hello', **model) }
    end

    it 'raises for streamed speech without a request' do
      expect_unsupported('speech generation') { RubyLLM.speak('Hello', **model) { |_chunk| nil } }
    end

    it 'raises for transcription without a request' do
      expect_unsupported('transcription') { RubyLLM.transcribe(audio_path, **model) }
    end

    it 'raises for streamed transcription without a request' do
      expect_unsupported('transcription') { RubyLLM.transcribe(audio_path, **model) { |_chunk| nil } }
    end

    it 'raises for image generation without a request' do
      expect_unsupported('image generation') { RubyLLM.paint('A red ruby', **model) }
    end

    it 'raises for moderation without a request' do
      expect_unsupported('moderation') { RubyLLM.moderate('Hello', **model) }
    end

    it 'raises for remote audio without downloading it' do
      expect_unsupported('transcription') { RubyLLM.transcribe('https://assets.example.com/ruby.wav', **model) }
    end

    it 'raises for streamed remote audio without downloading it' do
      expect_unsupported('transcription') do
        RubyLLM.transcribe('https://assets.example.com/ruby.wav', **model) { |_chunk| nil }
      end
    end

    it 'raises for a remote image to edit without downloading it' do
      expect_unsupported('image generation') do
        RubyLLM.paint('Make it blue', with: 'https://assets.example.com/ruby.png', **model)
      end
    end

    it 'raises for an image to embed before looking at it' do
      expect_unsupported('embeddings') do
        RubyLLM.embed('Hello', with: 'https://assets.example.com/ruby.png', **model)
      end
    end

    it 'raises for a local image to moderate without reading it' do
      image_path = File.expand_path('../../fixtures/ruby.png', __dir__)
      allow(File).to receive(:binread).and_call_original

      expect_unsupported('moderation') { RubyLLM.moderate('Hello', with: image_path, **model) }
      expect(File).not_to have_received(:binread).with(Pathname.new(image_path))
    end

    it 'raises for a remote image to moderate without downloading it' do
      expect_unsupported('moderation') do
        RubyLLM.moderate('Hello', with: 'https://assets.example.com/ruby.png', **model)
      end
    end
  end

  describe 'judgments' do
    let(:model) { RubyLLM::Model.default('clef:27b', 'ollama_cloud') }
    let(:question) { { urgent: { type: :probability, instructions: 'Is this urgent?' } } }

    before do
      RubyLLM.configure { |config| config.ollama_cloud_api_key = 'test' }
    end

    it 'judges through System One' do
      provider = described_class.new(RubyLLM.config)

      expect(provider.send(:resolve_protocol, nil, model, operation: :judge)).to eq(described_class::SystemOne)
    end

    it 'posts to systemone and raises what the API answers' do
      request = stub_request(:post, 'https://ollama.com/v1/systemone').to_return(
        status: 402, headers: { 'Content-Type' => 'application/json' },
        body: { error: 'this model is not included in your free usage, add usage credits to pay as you go: ' \
                       'https://ollama.com/settings or upgrade for included usage: https://ollama.com/upgrade. ' \
                       'Try gemma4:31b-cloud, which is in the Free plan. ' \
                       '(ref: 13ef7e0b-7246-4bc2-89e4-c4fff83c1c84)' }.to_json
      )

      expect do
        RubyLLM.judge('Help', model: 'clef:27b', provider: :ollama_cloud, assume_model_exists: true,
                              questions: question)
      end.to raise_error(RubyLLM::PaymentRequiredError, /not included in your free usage/)
      expect(request).to have_been_requested
    end
  end
end
