# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::ChatCompletions do
  def protocol_for(api_base, api_key: 'azure-key', auth_token: nil, model: nil)
    config = RubyLLM::Configuration.new.tap do |c|
      c.azure_api_base = api_base
      c.azure_api_key = api_key
      c.azure_ai_auth_token = auth_token
    end

    described_class.new(RubyLLM::Providers::Azure.new(config), model)
  end

  describe '#azure_endpoint' do
    it 'posts straight to a base that already names the chat endpoint' do
      protocol = protocol_for(
        'https://res.openai.azure.com/openai/deployments/gpt/chat/completions?api-version=2025-01-01'
      )

      expect(protocol.azure_endpoint(:chat)).to eq('')
    end

    it 'appends the chat path to a deployment base' do
      protocol = protocol_for('https://res.openai.azure.com/openai/deployments/gpt')

      expect(protocol.azure_endpoint(:chat)).to eq('chat/completions?api-version=2024-05-01-preview')
    end

    it 'keeps the api-version the deployment base already carries' do
      protocol = protocol_for('https://res.openai.azure.com/openai/deployments/gpt?api-version=2025-01-01')

      expect(protocol.azure_endpoint(:chat)).to eq('chat/completions?api-version=2025-01-01')
    end

    it 'omits the api-version on an openai/v1 base that does not pin one' do
      protocol = protocol_for('https://res.openai.azure.com/openai/v1')

      expect(protocol.azure_endpoint(:chat)).to eq('chat/completions')
    end

    it 'routes a resource base through the models path' do
      protocol = protocol_for('https://res.services.ai.azure.com')

      expect(protocol.azure_endpoint(:chat)).to eq('models/chat/completions?api-version=2024-05-01-preview')
    end

    it 'resolves embeddings relative to a deployment or openai/v1 base' do
      expect(protocol_for('https://res.openai.azure.com/openai/v1').azure_endpoint(:embeddings)).to eq('embeddings')
      expect(
        protocol_for('https://res.openai.azure.com/openai/deployments/ada?api-version=2025-01-01')
          .azure_endpoint(:embeddings)
      ).to eq('embeddings?api-version=2025-01-01')
    end

    it 'defaults the api-version on a deployment base that does not pin one' do
      protocol = protocol_for('https://res.openai.azure.com/openai/deployments/ada')

      expect(protocol.azure_endpoint(:embeddings)).to eq('embeddings?api-version=2024-05-01-preview')
    end

    it 'resolves embeddings against the host root for a resource base' do
      protocol = protocol_for('https://res.services.ai.azure.com')

      expect(protocol.azure_endpoint(:embeddings)).to eq('https://res.services.ai.azure.com/openai/v1/embeddings')
    end

    it 'resolves models relative to an openai/v1 base' do
      protocol = protocol_for('https://res.openai.azure.com/openai/v1')

      expect(protocol.azure_endpoint(:models)).to eq('models?api-version=preview')
    end

    it 'resolves models against the host root otherwise' do
      protocol = protocol_for('https://res.openai.azure.com/openai/deployments/gpt')

      expect(protocol.azure_endpoint(:models)).to eq(
        'https://res.openai.azure.com/openai/v1/models?api-version=preview'
      )
    end

    it 'rejects an unknown endpoint kind' do
      protocol = protocol_for('https://res.openai.azure.com/openai/v1')

      expect { protocol.azure_endpoint(:images) }.to raise_error(ArgumentError, /Unknown Azure endpoint kind/)
    end
  end

  describe 'provider base parsing' do
    it 'exposes an openai/v1 base as-is' do
      provider = protocol_for('https://res.openai.azure.com/openai/v1').instance_variable_get(:@provider)

      expect(provider.azure_openai_v1_base).to eq('https://res.openai.azure.com/openai/v1')
    end

    it 'derives the openai/v1 base from a deployment base' do
      provider = protocol_for('https://res.openai.azure.com/openai/deployments/gpt').instance_variable_get(:@provider)

      expect(provider.azure_openai_v1_base).to eq('https://res.openai.azure.com/openai/v1')
    end

    it 'strips trailing slashes before parsing' do
      provider = protocol_for('https://res.services.ai.azure.com/').instance_variable_get(:@provider)

      expect(provider.azure_base_parts).to include(
        path_base: 'https://res.services.ai.azure.com',
        root: 'https://res.services.ai.azure.com',
        mode: :resource_base,
        version: nil
      )
    end
  end

  describe 'authentication' do
    it 'sends the api key when one is configured' do
      provider = protocol_for('https://res.openai.azure.com/openai/v1').instance_variable_get(:@provider)

      expect(provider.headers).to eq('api-key' => 'azure-key')
    end

    it 'falls back to a bearer token' do
      provider = protocol_for(
        'https://res.openai.azure.com/openai/v1', api_key: nil, auth_token: 'entra-token'
      ).instance_variable_get(:@provider)

      expect(provider.headers).to eq('Authorization' => 'Bearer entra-token')
    end

    it 'reports both missing settings' do
      config = RubyLLM::Configuration.new

      expect { RubyLLM::Providers::Azure.new(config) }.to raise_error(
        RubyLLM::ConfigurationError, /azure_api_base, azure_api_key or azure_ai_auth_token/
      )
    end

    it 'reports only the missing credential' do
      config = RubyLLM::Configuration.new.tap { |c| c.azure_api_base = 'https://res.openai.azure.com/openai/v1' }

      expect { RubyLLM::Providers::Azure.new(config) }.to raise_error(
        RubyLLM::ConfigurationError, /Missing configuration for Azure: azure_api_key or azure_ai_auth_token/
      )
    end
  end

  describe 'usage' do
    let(:grok_usage) do
      { 'prompt_tokens' => 212, 'completion_tokens' => 18, 'total_tokens' => 230,
        'prompt_tokens_details' => { 'text_tokens' => 212, 'cached_tokens' => 159 } }
    end

    let(:openai_usage) do
      { 'prompt_tokens' => 2_048, 'completion_tokens' => 18, 'total_tokens' => 2_066,
        'prompt_tokens_details' => { 'cached_tokens' => 1_024 } }
    end

    def completion_tokens(model, usage)
      body = { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Done' } }], 'usage' => usage }

      protocol_for('https://res.services.ai.azure.com', model: model)
        .send(:parse_completion_body, body, raw: nil).tokens
    end

    it 'reports every prompt token of a Grok reply as input beside its cache reads' do
      grok = RubyLLM.models.find('grok-4-1-fast-non-reasoning', provider: :azure)

      expect(completion_tokens(grok, grok_usage)).to have_attributes(input: 212, output: 18, cache_read: 159)
    end

    it 'reports every prompt token of a streamed Grok reply as input' do
      grok = RubyLLM.models.find('grok-4-1-fast-non-reasoning', provider: :azure)
      chunk = protocol_for('https://res.services.ai.azure.com', model: grok)
              .send(:build_chunk, { 'choices' => [{ 'delta' => {} }], 'usage' => grok_usage })

      expect(chunk.tokens).to have_attributes(input: 212, cache_read: 159)
    end

    it 'keeps the prompt tokens when the cache reads exceed them' do
      grok = RubyLLM.models.find('grok-4-1-fast-non-reasoning', provider: :azure)
      usage = { 'prompt_tokens' => 7, 'completion_tokens' => 1, 'total_tokens' => 8,
                'prompt_tokens_details' => { 'text_tokens' => 7, 'cached_tokens' => 162 } }

      expect(completion_tokens(grok, usage)).to have_attributes(input: 7, cache_read: 162)
    end

    it 'reads a deployment of a Grok model the same way' do
      config = RubyLLM::Configuration.new.tap do |c|
        c.azure_deployments = { 'prod-chat' => 'grok-4-1-fast-non-reasoning' }
      end
      deployment = RubyLLM.models.find('prod-chat', provider: :azure, config: config)

      expect(completion_tokens(deployment, grok_usage)).to have_attributes(input: 212, cache_read: 159)
    end

    it 'reads a Grok model the registry lists without a family the same way' do
      grok = RubyLLM::Model.new(id: 'grok-4.3', provider: 'azure')

      expect(completion_tokens(grok, grok_usage)).to have_attributes(input: 212, cache_read: 159)
    end

    it 'subtracts cache reads from the prompt tokens of other models' do
      gpt = RubyLLM.models.find('gpt-5-nano', provider: :azure)

      expect(completion_tokens(gpt, openai_usage)).to have_attributes(input: 1_024, cache_read: 1_024)
    end

    it 'subtracts cache reads when no model is known, as in batch results' do
      expect(completion_tokens(nil, openai_usage)).to have_attributes(input: 1_024, cache_read: 1_024)
    end
  end
end
