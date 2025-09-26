# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::RedCandle do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { described_class.new(config) }

  # Skip all tests if Red Candle is not available
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    require 'candle'
  rescue LoadError
    skip 'Red Candle gem is not installed'
  end

  describe '#initialize' do
    context 'when Red Candle is not available' do
      before do
        allow_any_instance_of(described_class).to receive(:require).with('candle').and_raise(LoadError) # rubocop:disable RSpec/AnyInstance
      end

      it 'raises an informative error' do
        expect { described_class.new(config) }.to raise_error(
          RubyLLM::Error,
          /Red Candle gem is not installed/
        )
      end
    end

    context 'with device configuration' do
      it 'uses the configured device' do
        config.red_candle_device = 'cpu'
        provider = described_class.new(config)
        expect(provider.instance_variable_get(:@device)).to eq(Candle::Device.cpu)
      end

      it 'defaults to best device when not configured' do
        provider = described_class.new(config)
        expect(provider.instance_variable_get(:@device)).to eq(Candle::Device.best)
      end
    end
  end

  describe '#api_base' do
    it 'returns nil for local execution' do
      expect(provider.api_base).to be_nil
    end
  end

  describe '#headers' do
    it 'returns empty hash' do
      expect(provider.headers).to eq({})
    end
  end

  describe '.local?' do
    it 'returns true' do
      expect(described_class.local?).to be true
    end
  end

  describe '.configuration_requirements' do
    it 'returns empty array' do
      expect(described_class.configuration_requirements).to eq([])
    end
  end

  describe '.capabilities' do
    it 'returns the Capabilities module' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::RedCandle::Capabilities)
    end
  end
end
