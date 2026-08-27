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
    expect(RubyLLM::Provider.remote_providers).to include(ollama_cloud: described_class)
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
end
