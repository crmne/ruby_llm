# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Provider do
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
end
