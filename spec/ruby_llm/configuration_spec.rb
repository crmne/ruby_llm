# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Configuration do
  describe 'DSL defaults' do
    subject(:config) { described_class.new }

    it 'applies core default values' do
      expect(config.model_registry_class).to eq('Model')
      expect(config.model_registry_source).to be_nil
      expect(config.request_timeout).to eq(300)
      expect(config.max_retries).to eq(3)
      expect(config.retry_interval).to eq(0.1)
      expect(config.retry_backoff_factor).to eq(2)
      expect(config.retry_interval_randomness).to eq(0.5)
      expect(config.tool_concurrency).to be(false)
      expect(config.deprecation_behavior).to eq(:warn)
      expect(config.faraday_adapter).to eq(:net_http)
    end

    it 'exposes a discoverable options API' do
      expect(described_class.options).to include(
        :request_timeout,
        :tool_concurrency,
        :default_model,
        :default_speech_model,
        :model_registry_file,
        :openai_api_key,
        :llm_gateway_api_base,
        :openrouter_api_base
      )
    end

    it 'normalizes blank strings to nil' do
      config.openai_api_base = ''
      config.anthropic_api_key = " \t\n"

      expect(config.openai_api_base).to be_nil
      expect(config.anthropic_api_key).to be_nil
    end

    it 'preserves non-blank strings' do
      config.openai_api_base = 'https://openai-compatible.example.com/v1'

      expect(config.openai_api_base).to eq('https://openai-compatible.example.com/v1')
    end

    it 'omits credential providers from instance variables' do
      config.bedrock_credential_provider = Object.new

      expect(config.instance_variables).not_to include(:@bedrock_credential_provider)
    end

    it 'warns but preserves log_regexp_timeout when regexp timeouts are unsupported' do
      allow(Regexp).to receive(:respond_to?).and_call_original
      allow(Regexp).to receive(:respond_to?).with(:timeout).and_return(false)
      allow(RubyLLM.logger).to receive(:warn)

      config.log_regexp_timeout = 5.0

      expect(config.log_regexp_timeout).to eq(5.0)
      expect(RubyLLM.logger).to have_received(:warn).with(
        "log_regexp_timeout is not supported on Ruby #{RUBY_VERSION}"
      )
    end
  end
end
