# frozen_string_literal: true

require 'spec_helper'

# Each provider uses its base URL setting as given, and refuses one that has
# no scheme or already ends in an endpoint path RubyLLM adds itself.
RSpec.describe RubyLLM::Provider do
  def provider_with(slug, settings)
    config = RubyLLM::Configuration.new
    config.public_send(:"#{slug}_api_key=", 'key') if config.respond_to?(:"#{slug}_api_key=")
    { bedrock_region: 'us-east-1', bedrock_secret_key: 'secret', vertexai_project_id: 'proj',
      vertexai_location: 'us-central1' }.each { |setting, value| config.public_send(:"#{setting}=", value) }
    settings.each { |setting, value| config.public_send(:"#{setting}=", value) }
    described_class.providers.fetch(slug).new(config)
  end

  {
    openai: [:openai_api_base, 'https://api.openai.com/v1', '/chat/completions', '/responses', '/embeddings'],
    mistral: [:mistral_api_base, 'https://api.mistral.ai/v1', '/chat/completions'],
    xai: [:xai_api_base, 'https://api.x.ai/v1', '/responses'],
    moonshot: [:moonshot_api_base, 'https://api.moonshot.ai/v1', '/chat/completions'],
    hetzner: [:hetzner_api_base, 'https://inference.hetzner.com/v1', '/chat/completions'],
    meta: [:meta_api_base, 'https://api.meta.ai/v1', '/responses'],
    ollama: [:ollama_api_base, 'http://localhost:11434/v1', '/chat/completions'],
    ollama_cloud: [:ollama_cloud_api_base, 'https://ollama.com/v1', '/chat/completions'],
    gpustack: [:gpustack_api_base, 'http://HOST/v1', '/chat/completions'],
    openrouter: [:openrouter_api_base, 'https://openrouter.ai/api/v1', '/chat/completions'],
    zai: [:zai_api_base, 'https://api.z.ai/api/paas/v4', '/chat/completions'],
    deepseek: [:deepseek_api_base, 'https://api.deepseek.com', '/chat/completions'],
    perplexity: [:perplexity_api_base, 'https://api.perplexity.ai', '/chat/completions', '/v1/agent', '/v1/embeddings'],
    anthropic: [:anthropic_api_base, 'https://api.anthropic.com', '/v1/messages'],
    minimax: [:minimax_api_base, 'https://api.minimax.io/anthropic', '/v1/messages'],
    cohere: [:cohere_api_base, 'https://api.cohere.com', '/v2/chat'],
    deepgram: [:deepgram_api_base, 'https://api.deepgram.com', '/v1/listen'],
    elevenlabs: [:elevenlabs_api_base, 'https://api.elevenlabs.io', '/v1/speech-to-text', '/v1/text-to-speech/VOICE'],
    typesafe: [:typesafe_api_base, 'https://api.typesafe.ai', '/v1/systemone'],
    gemini: [:gemini_api_base, 'https://generativelanguage.googleapis.com/v1beta',
             '/models/gemini-2.5-flash:generateContent'],
    bedrock: [:bedrock_api_base, 'https://bedrock-runtime.us-east-1.amazonaws.com',
              '/model/amazon.nova-lite-v1:0/converse'],
    vertexai: [:vertexai_api_base, 'https://LOCATION-aiplatform.googleapis.com/v1beta1',
               '/projects/proj/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent']
  }.each do |slug, (setting, base, *endpoints)|
    describe setting.to_s do
      it 'uses the documented form as given, with or without a trailing slash' do
        expect([base, "#{base}/"].map do |form|
          provider_with(slug, setting => form).api_base
        end).to eq([base, "#{base}/"])
      end

      endpoints.each do |endpoint|
        it "raises for a base ending in #{endpoint}, naming the expected form" do
          expect { provider_with(slug, setting => "#{base}#{endpoint}/") }.to raise_error(
            RubyLLM::ConfigurationError,
            "#{setting} should look like #{base} (without #{endpoint}), got #{"#{base}#{endpoint}/".inspect}"
          )
        end
      end

      it 'raises for a base without a scheme' do
        form = base.delete_prefix('https://').delete_prefix('http://')

        expect { provider_with(slug, setting => form) }.to raise_error(
          RubyLLM::ConfigurationError, %r{\A#{setting} should look like .+, starting with http:// or https://, got}
        )
      end
    end
  end

  it 'checks the bedrock-mantle base for endpoint paths' do
    expect do
      provider_with(:bedrock, bedrock_mantle_api_base: 'https://bedrock-mantle.us-east-1.api.aws/v1/chat/completions')
        .mantle_api_base
    end.to raise_error(RubyLLM::ConfigurationError, %r{without /chat/completions})
  end

  it 'ignores a query string when looking for an endpoint path' do
    base = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse'

    expect { provider_with(:gemini, gemini_api_base: base) }.to raise_error(
      RubyLLM::ConfigurationError, /without .*:streamGenerateContent\)/
    )
  end

  it 'keeps a gateway prefix as given' do
    provider = provider_with(:openai, openai_api_base: 'https://gateway.example.com/openai')

    expect(provider.api_base).to eq('https://gateway.example.com/openai')
  end

  describe 'azure_api_base' do
    it 'raises for a base without a scheme' do
      expect { provider_with(:azure, azure_api_base: 'res.openai.azure.com') }.to raise_error(
        RubyLLM::ConfigurationError, %r{azure_api_base should look like https://RESOURCE.openai.azure.com}
      )
    end

    it 'treats a base ending in /models as the resource' do
      provider = provider_with(:azure, azure_api_base: 'https://res.services.ai.azure.com/models/?api-version=2025-01-01')

      expect(provider.api_base).to eq('https://res.services.ai.azure.com?api-version=2025-01-01')
    end

    it 'treats a base ending in /openai/v1/responses as the openai/v1 base' do
      provider = provider_with(:azure, azure_api_base: 'https://res.openai.azure.com/openai/v1/responses/')

      expect(provider.api_base).to eq('https://res.openai.azure.com/openai/v1')
    end

    it 'leaves a deployment named models alone' do
      provider = provider_with(:azure, azure_api_base: 'https://res.openai.azure.com/openai/deployments/models')

      expect(provider.api_base).to eq('https://res.openai.azure.com/openai/deployments/models')
    end
  end
end
