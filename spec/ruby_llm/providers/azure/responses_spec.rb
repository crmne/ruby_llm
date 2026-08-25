# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Responses do
  def provider_for(api_base, protocol: nil)
    config = RubyLLM::Configuration.new.tap do |c|
      c.azure_api_base = api_base
      c.azure_api_key = 'azure-key'
      c.azure_protocol = protocol
    end

    RubyLLM::Providers::Azure.new(config)
  end

  describe '#completion_url' do
    it 'posts to the openai/v1 responses endpoint from a resource base' do
      protocol = described_class.new(provider_for('https://res.services.ai.azure.com'))

      expect(protocol.completion_url).to eq('https://res.services.ai.azure.com/openai/v1/responses')
    end

    it 'reuses an openai/v1 base as-is' do
      protocol = described_class.new(provider_for('https://res.openai.azure.com/openai/v1'))

      expect(protocol.completion_url).to eq('https://res.openai.azure.com/openai/v1/responses')
    end

    it 'derives the openai/v1 base from a deployment base' do
      protocol = described_class.new(provider_for('https://res.openai.azure.com/openai/deployments/gpt'))

      expect(protocol.completion_url).to eq('https://res.openai.azure.com/openai/v1/responses')
    end
  end

  describe '#render' do
    it 'sends the deployment name in the model field' do
      model = instance_double(RubyLLM::Model, id: 'my-deployment')
      protocol = described_class.new(provider_for('https://res.services.ai.azure.com'), model)

      payload = protocol.render(
        [RubyLLM::Message.new(role: :user, content: 'Hello')], tools: {}, temperature: nil
      )

      expect(payload[:model]).to eq('my-deployment')
      expect(payload[:input]).to eq([{ role: 'user', content: 'Hello' }])
    end
  end

  describe '#server_tool_aliases' do
    it 'drops web_search and keeps the rest of the Responses table' do
      protocol = described_class.new(provider_for('https://res.services.ai.azure.com'))

      expect(protocol.server_tool_aliases).not_to have_key(:web_search)
      expect(protocol.server_tool_aliases.keys).to eq(
        RubyLLM::Protocols::Responses::SERVER_TOOL_ALIASES.keys - [:web_search]
      )
    end
  end

  describe 'protocol routing' do
    let(:provider) { provider_for('https://res.services.ai.azure.com') }

    it 'keeps chat completions as the default' do
      model = instance_double(RubyLLM::Model, id: 'grok-4-1-fast-non-reasoning')

      expect(RubyLLM::Providers::Azure.default_protocol).to eq(:chat_completions)
      expect(provider.send(:resolve_protocol, nil, model)).to eq(RubyLLM::Providers::Azure::ChatCompletions)
    end

    it 'routes gpt-5.4+ deployment names to Responses' do
      %w[gpt-5.4 gpt-5.6-terra gpt-56].each do |id|
        model = instance_double(RubyLLM::Model, id: id)

        expect(provider.send(:resolve_protocol, nil, model)).to eq(described_class)
      end
    end

    it 'honors an explicit protocol over the routing' do
      model = instance_double(RubyLLM::Model, id: 'gpt-5.6-terra')

      expect(provider.send(:resolve_protocol, :chat_completions, model)).to eq(
        RubyLLM::Providers::Azure::ChatCompletions
      )
    end

    it 'honors the azure_protocol configuration option' do
      provider = provider_for('https://res.services.ai.azure.com', protocol: :responses)
      model = instance_double(RubyLLM::Model, id: 'grok-4-1-fast-non-reasoning')

      expect(provider.send(:resolve_protocol, nil, model)).to eq(described_class)
    end
  end

  describe 'a GPT-5.6 deployment', :live do
    include_context 'with configured RubyLLM'

    # rubocop:disable-next Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    class AzureWeather < RubyLLM::Tool
      description 'Gets current weather for a city'
      parameter :city, description: 'City name'

      def execute(city:)
        "Current weather in #{city}: 15C, wind 10 km/h"
      end
    end

    let(:chat) { RubyLLM.chat(model: 'gpt-5.6-luna', provider: :azure, assume_model_exists: true) }

    it 'routes to Responses without being asked' do
      response = chat.ask('Say OK and nothing else.')

      expect(response.content).to include('OK')
    end

    it 'calls tools, which this model generation rejects on Chat Completions' do
      response = chat.with_tools(AzureWeather).ask("What's the weather in Berlin? Use the tool.")

      expect(response.content).to include('15')
    end
  end
end
