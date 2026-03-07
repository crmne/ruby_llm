# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Configuration do
  describe 'DSL defaults' do
    subject(:config) { described_class.new }

    it 'applies core default values' do
      expect(config.model_registry_class).to eq('Model')
      expect(config.use_new_acts_as).to be(false)
      expect(config.request_timeout).to eq(300)
      expect(config.max_retries).to eq(3)
      expect(config.retry_interval).to eq(0.1)
      expect(config.retry_backoff_factor).to eq(2)
      expect(config.retry_interval_randomness).to eq(0.5)
    end

    it 'exposes a discoverable options API' do
      expect(described_class.options).to include(
        :request_timeout,
        :default_model,
        :model_registry_file,
        :openai_api_key,
        :openrouter_api_base
      )
    end
  end
end
