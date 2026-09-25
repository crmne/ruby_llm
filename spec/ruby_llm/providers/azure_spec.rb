# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure do
  let(:config) do
    RubyLLM::Configuration.new.tap do |azure_config|
      azure_config.azure_api_base = 'https://acme.openai.azure.com'
      azure_config.azure_api_key = 'test-key'
      azure_config.azure_deployments = { 'gpt-4o-global' => 'gpt-4o' }
    end
  end

  describe 'azure_deployments' do
    let(:gpt4o) do
      RubyLLM::Model.new(
        id: 'gpt-4o', provider: 'azure', context_window: 128_000, capabilities: %w[function_calling],
        pricing: { text_tokens: { standard: { input_per_million: 2.5, output_per_million: 10.0 } } }
      )
    end
    let(:registry) { RubyLLM::Models.new([gpt4o]) }

    it 'finds a declared deployment under its own name with the model it deploys' do
      model = registry.find('gpt-4o-global', provider: :azure, config: config)

      expect(model.id).to eq('gpt-4o-global')
      expect(model.to_h.except(:id)).to eq(gpt4o.to_h.except(:id))
    end

    it 'accepts Symbol keys and values' do
      config.azure_deployments = { 'gpt-4o-global': :'gpt-4o' }

      model = registry.find('gpt-4o-global', provider: :azure, config: config)

      expect([model.id, model.context_window]).to eq(['gpt-4o-global', 128_000])
    end

    it 'resolves an alias the deployment points to' do
      config.azure_deployments = { 'my-haiku' => 'claude-haiku-4-5' }
      haiku = RubyLLM::Model.new(id: 'claude-haiku-4-5-20251001', provider: 'azure', context_window: 200_000)

      model = RubyLLM::Models.new([haiku]).find('my-haiku', provider: :azure, config: config)

      expect([model.id, model.context_window]).to eq(['my-haiku', 200_000])
    end

    it 'prefers a declared deployment over an alias with the same name' do
      config.azure_deployments = { 'claude-opus-4-5' => 'gpt-4o' }
      opus = RubyLLM::Model.new(id: 'claude-opus-4-5-20251101', provider: 'azure', context_window: 200_000)

      model = RubyLLM::Models.new([gpt4o, opus]).find('claude-opus-4-5', provider: :azure, config: config)

      expect([model.id, model.context_window]).to eq(['claude-opus-4-5', 128_000])
    end

    it 'leaves undeclared names as they are' do
      expect(registry.find('gpt-4o', provider: :azure, config: config)).to be(gpt4o)
      expect { registry.find('my-deployment', provider: :azure, config: config) }
        .to raise_error(RubyLLM::ModelNotFoundError)
    end

    it 'gives a chat the deployment name and the registry entry instead of an assumed model' do
      chat = RubyLLM.context do |context_config|
        context_config.azure_api_base = config.azure_api_base
        context_config.azure_api_key = config.azure_api_key
        context_config.azure_deployments = config.azure_deployments
      end.chat(model: 'gpt-4o-global', provider: :azure)

      expect(chat.model.id).to eq('gpt-4o-global')
      expect(chat.model.metadata).to eq(RubyLLM.models.find('gpt-4o', provider: :azure).metadata)
    end
  end
end
