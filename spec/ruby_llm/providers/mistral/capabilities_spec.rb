# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Capabilities do
  describe '.supports_reasoning?' do
    it 'recognizes native and adjustable reasoning models' do
      expect(described_class.supports_reasoning?('magistral-small-latest')).to be(true)
      expect(described_class.supports_reasoning?('mistral-small-latest')).to be(true)
      expect(described_class.supports_reasoning?('mistral-medium-3-5')).to be(true)
      expect(described_class.supports_reasoning?('mistral-medium-3.5')).to be(true)
      expect(described_class.supports_reasoning?('pixtral-12b')).to be(false)
    end
  end
end
