# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers do
  include_context 'with configured RubyLLM'

  let(:config) { RubyLLM.config }

  describe RubyLLM::Providers::DeepSeek do
    subject(:provider) { described_class.new(config) }

    it 'returns the expected api base' do
      expect(provider.api_base).to eq('https://api.deepseek.com')
    end

    it 'returns auth headers' do
      expect(provider.headers).to eq(
        'Authorization' => "Bearer #{config.deepseek_api_key}"
      )
    end
  end

  describe RubyLLM::Providers::Mistral do
    subject(:provider) { described_class.new(config) }

    it 'returns the expected api base' do
      expect(provider.api_base).to eq('https://api.mistral.ai/v1')
    end

    it 'returns auth headers' do
      expect(provider.headers).to eq(
        'Authorization' => "Bearer #{config.mistral_api_key}"
      )
    end
  end

  describe RubyLLM::Providers::OpenRouter do
    subject(:provider) { described_class.new(config) }

    it 'returns the expected api base' do
      expect(provider.api_base).to eq('https://openrouter.ai/api/v1')
    end

    it 'returns auth headers' do
      expect(provider.headers).to eq(
        'Authorization' => "Bearer #{config.openrouter_api_key}"
      )
    end
  end

  describe RubyLLM::Providers::Perplexity do
    subject(:provider) { described_class.new(config) }

    it 'returns the expected api base' do
      expect(provider.api_base).to eq('https://api.perplexity.ai')
    end

    it 'returns auth headers' do
      expect(provider.headers).to eq(
        'Authorization' => "Bearer #{config.perplexity_api_key}",
        'Content-Type' => 'application/json'
      )
    end

    it 'extracts error messages from HTML auth responses' do
      response = instance_double(
        Faraday::Response,
        body: '<html><head><title>401 Unauthorized</title></head></html>'
      )

      expect(provider.parse_error(response)).to eq('Unauthorized')
    end
  end

  describe RubyLLM::Providers::Ollama do
    subject(:provider) { described_class.new(config) }

    it 'returns the configured api base' do
      expect(provider.api_base).to eq(config.ollama_api_base)
    end

    it 'returns empty headers' do
      expect(provider.headers).to eq({})
    end
  end

  describe RubyLLM::Providers::GPUStack do
    subject(:provider) { described_class.new(config) }

    before do
      config.gpustack_api_key = nil
    end

    it 'returns the configured api base' do
      expect(provider.api_base).to eq(config.gpustack_api_base)
    end

    it 'returns empty headers when no api key is set' do
      expect(provider.headers).to eq({})
    end

    it 'returns auth headers when an api key is set' do
      config.gpustack_api_key = 'gpu-test'

      expect(provider.headers).to eq(
        'Authorization' => 'Bearer gpu-test'
      )
    end
  end

  describe RubyLLM::Providers::VertexAI do
    subject(:provider) { described_class.new(config) }

    it 'returns the configured api base' do
      expect(provider.api_base).to eq(
        "https://#{config.vertexai_location}-aiplatform.googleapis.com/v1beta1"
      )
    end

    it 'returns the test token when VCR is present and not recording' do
      allow(VCR.current_cassette).to receive(:recording?).and_return(false)

      expect(provider.headers).to eq(
        'Authorization' => 'Bearer test-token'
      )
    end
  end
end
