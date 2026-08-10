# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::ChatCompletions do
  def protocol_for(api_base, api_key: 'azure-key', auth_token: nil)
    config = RubyLLM::Configuration.new.tap do |c|
      c.azure_api_base = api_base
      c.azure_api_key = api_key
      c.azure_ai_auth_token = auth_token
    end

    described_class.new(RubyLLM::Providers::Azure.new(config))
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
end
