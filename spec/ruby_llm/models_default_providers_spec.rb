# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Models do
  include_context 'with configured RubyLLM'

  let(:anthropic_model) do
    RubyLLM::Model::Info.new(
      id: 'claude-sonnet-4-5',
      name: 'Claude Sonnet 4.5',
      provider: 'anthropic',
      family: 'claude-sonnet'
    )
  end

  let(:bedrock_model) do
    RubyLLM::Model::Info.new(
      id: 'claude-sonnet-4-5',
      name: 'Claude Sonnet 4.5',
      provider: 'bedrock',
      family: 'claude-sonnet'
    )
  end

  let(:haiku_anthropic) do
    RubyLLM::Model::Info.new(
      id: 'claude-haiku-4-5',
      name: 'Claude Haiku 4.5',
      provider: 'anthropic',
      family: 'claude-haiku'
    )
  end

  let(:haiku_bedrock) do
    RubyLLM::Model::Info.new(
      id: 'claude-haiku-4-5',
      name: 'Claude Haiku 4.5',
      provider: 'bedrock',
      family: 'claude-haiku'
    )
  end

  after do
    described_class.instance_variable_set(:@instance, nil)
    RubyLLM.configure do |config|
      config.default_providers = {}
    end
  end

  describe 'default_providers' do
    it 'routes models to the configured provider by prefix match' do
      models = described_class.new([anthropic_model, bedrock_model])

      RubyLLM.configure do |config|
        config.default_providers = { 'claude' => :bedrock }
      end

      model, provider = models.resolve('claude-sonnet-4-5')
      expect(model.provider).to eq('bedrock')
      expect(provider).to be_a(RubyLLM::Provider)
    end

    it 'prefers longer (more specific) keys' do
      models = described_class.new([haiku_anthropic, haiku_bedrock, anthropic_model, bedrock_model])

      RubyLLM.configure do |config|
        config.default_providers = {
          'claude' => :bedrock,
          'claude-haiku' => :anthropic
        }
      end

      # claude-haiku matches the longer key → anthropic
      model, _provider = models.resolve('claude-haiku-4-5')
      expect(model.provider).to eq('anthropic')

      # claude-sonnet only matches 'claude' → bedrock
      model, _provider = models.resolve('claude-sonnet-4-5')
      expect(model.provider).to eq('bedrock')
    end

    it 'does not apply when an explicit provider: is passed' do
      models = described_class.new([anthropic_model, bedrock_model])

      RubyLLM.configure do |config|
        config.default_providers = { 'claude' => :bedrock }
      end

      model, _provider = models.resolve('claude-sonnet-4-5', provider: :anthropic)
      expect(model.provider).to eq('anthropic')
    end

    it 'falls through to normal resolution when no prefix matches' do
      models = described_class.new([anthropic_model, bedrock_model])

      RubyLLM.configure do |config|
        config.default_providers = { 'gpt' => :azure }
      end

      # 'claude-sonnet-4-5' doesn't match 'gpt', so default_providers is skipped
      # and normal PROVIDER_PREFERENCE applies (anthropic before bedrock)
      model, _provider = models.resolve('claude-sonnet-4-5')
      expect(model.provider).to eq('anthropic')
    end

    it 'works with an empty hash (no-op)' do
      models = described_class.new([anthropic_model, bedrock_model])

      RubyLLM.configure do |config|
        config.default_providers = {}
      end

      # Falls through to default PROVIDER_PREFERENCE (anthropic before bedrock)
      model, _provider = models.resolve('claude-sonnet-4-5')
      expect(model.provider).to eq('anthropic')
    end
  end
end
