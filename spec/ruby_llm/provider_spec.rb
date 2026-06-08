# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider do
  def api_base_cases
    {
      anthropic: {
        provider: RubyLLM::Providers::Anthropic,
        key: :anthropic_api_base,
        custom: 'https://anthropic-proxy.example.com',
        default: 'https://api.anthropic.com'
      },
      azure: {
        provider: RubyLLM::Providers::Azure,
        key: :azure_api_base,
        custom: 'https://azure-resource.example.com'
      },
      bedrock: {
        provider: RubyLLM::Providers::Bedrock,
        key: :bedrock_api_base,
        custom: 'https://bedrock-proxy.example.com',
        default: 'https://bedrock-runtime.us-east-1.amazonaws.com'
      },
      deepseek: {
        provider: RubyLLM::Providers::DeepSeek,
        key: :deepseek_api_base,
        custom: 'https://deepseek-proxy.example.com',
        default: 'https://api.deepseek.com'
      },
      gemini: {
        provider: RubyLLM::Providers::Gemini,
        key: :gemini_api_base,
        custom: 'https://gemini-proxy.example.com/v1',
        default: 'https://generativelanguage.googleapis.com/v1beta'
      },
      gpustack: {
        provider: RubyLLM::Providers::GPUStack,
        key: :gpustack_api_base,
        custom: 'https://gpustack.example.com/v1'
      },
      mistral: {
        provider: RubyLLM::Providers::Mistral,
        key: :mistral_api_base,
        custom: 'https://mistral-proxy.example.com/v1',
        default: 'https://api.mistral.ai/v1'
      },
      ollama: {
        provider: RubyLLM::Providers::Ollama,
        key: :ollama_api_base,
        custom: 'https://ollama.example.com/v1'
      },
      openai: {
        provider: RubyLLM::Providers::OpenAI,
        key: :openai_api_base,
        custom: 'https://openai-proxy.example.com/v1',
        default: 'https://api.openai.com/v1'
      },
      openrouter: {
        provider: RubyLLM::Providers::OpenRouter,
        key: :openrouter_api_base,
        custom: 'https://openrouter-proxy.example.com/api/v1',
        default: 'https://openrouter.ai/api/v1'
      },
      perplexity: {
        provider: RubyLLM::Providers::Perplexity,
        key: :perplexity_api_base,
        custom: 'https://perplexity-proxy.example.com',
        default: 'https://api.perplexity.ai'
      },
      vertexai: {
        provider: RubyLLM::Providers::VertexAI,
        key: :vertexai_api_base,
        custom: 'https://vertex-proxy.example.com/v1beta1',
        default: 'https://us-east1-aiplatform.googleapis.com/v1beta1'
      },
      xai: {
        provider: RubyLLM::Providers::XAI,
        key: :xai_api_base,
        custom: 'https://xai-proxy.example.com/v1',
        default: 'https://api.x.ai/v1'
      }
    }
  end

  def config_for(slug)
    RubyLLM::Configuration.new.tap do |config|
      case slug
      when :anthropic
        config.anthropic_api_key = 'anthropic-key'
      when :azure
        config.azure_api_key = 'azure-key'
      when :bedrock
        config.bedrock_api_key = 'bedrock-key'
        config.bedrock_secret_key = 'bedrock-secret'
        config.bedrock_region = 'us-east-1'
      when :deepseek
        config.deepseek_api_key = 'deepseek-key'
      when :gemini
        config.gemini_api_key = 'gemini-key'
      when :gpustack
        config.gpustack_api_key = 'gpustack-key'
      when :mistral
        config.mistral_api_key = 'mistral-key'
      when :ollama
        config.ollama_api_key = 'ollama-key'
      when :openai
        config.openai_api_key = 'openai-key'
      when :openrouter
        config.openrouter_api_key = 'openrouter-key'
      when :perplexity
        config.perplexity_api_key = 'perplexity-key'
      when :vertexai
        config.vertexai_project_id = 'vertex-project'
        config.vertexai_location = 'us-east1'
      when :xai
        config.xai_api_key = 'xai-key'
      end
    end
  end

  describe '.register' do
    it 'registers provider configuration options on Configuration' do
      provider_key = :test_provider_spec
      option_keys = %i[test_provider_api_key test_provider_api_base]

      provider_class = Class.new(described_class) do
        class << self
          def configuration_options
            %i[test_provider_api_key test_provider_api_base]
          end

          def configuration_requirements
            %i[test_provider_api_key]
          end
        end
      end

      original_providers = described_class.providers.dup

      begin
        described_class.register(provider_key, provider_class)

        config = RubyLLM::Configuration.new
        option_keys.each do |key|
          expect(config).to respond_to(key)
          expect(config).to respond_to("#{key}=")
        end
      ensure
        described_class.providers.replace(original_providers)
        option_keys.each do |key|
          RubyLLM::Configuration.send(:option_keys).delete(key)
          RubyLLM::Configuration.send(:defaults).delete(key)
          RubyLLM::Configuration.class_eval do
            remove_method key if method_defined?(key)
            remove_method :"#{key}=" if method_defined?(:"#{key}=")
          end
        end
      end
    end
  end

  describe '.configured?' do
    it 'treats blank required configuration as missing' do
      provider_class = Class.new(described_class) do
        class << self
          def configuration_options
            %i[blank_test_api_key]
          end

          def configuration_requirements
            %i[blank_test_api_key]
          end
        end
      end

      RubyLLM::Configuration.register_provider_options(provider_class.configuration_options)
      config = RubyLLM::Configuration.new
      config.blank_test_api_key = ''

      expect(provider_class.configured?(config)).to be(false)
    ensure
      RubyLLM::Configuration.send(:option_keys).delete(:blank_test_api_key)
      RubyLLM::Configuration.send(:defaults).delete(:blank_test_api_key)
      RubyLLM::Configuration.class_eval do
        remove_method :blank_test_api_key if method_defined?(:blank_test_api_key)
        remove_method :blank_test_api_key= if method_defined?(:blank_test_api_key=)
      end
    end
  end

  describe 'provider configuration schema' do
    it 'keeps requirements as a subset of declared configuration options' do
      described_class.providers.each_value do |provider_class|
        missing = provider_class.configuration_requirements - provider_class.configuration_options
        expect(missing).to be_empty, "#{provider_class.name} is missing options for requirements: #{missing.inspect}"
      end
    end

    it 'exposes aggregated provider options through Configuration' do
      expect(RubyLLM::Configuration.options).to include(
        :openrouter_api_base,
        :deepseek_api_base,
        :ollama_api_key
      )

      expect(RubyLLM::Configuration.options).to include(
        :request_timeout,
        :model_registry_class
      )
    end
  end

  context 'with API base configuration' do
    it 'covers every registered provider' do
      expect(api_base_cases.keys).to match_array(described_class.providers.keys)
    end

    it 'registers an API base option for every provider' do
      expected_options = api_base_cases.values.map { |data| data[:key] }

      expect(RubyLLM::Configuration.options).to include(*expected_options)
    end

    it 'uses the configured API base for every provider' do
      api_base_cases.each do |slug, data|
        config = config_for(slug)
        config.public_send("#{data[:key]}=", data[:custom])

        expect(data[:provider].new(config).api_base).to eq(data[:custom])
      end
    end

    it 'keeps existing defaults for providers with built-in endpoints' do
      api_base_cases.each do |slug, data|
        next unless data[:default]

        expect(data[:provider].new(config_for(slug)).api_base).to eq(data[:default])
      end
    end
  end
end
