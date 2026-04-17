# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Temperature do
  describe '.normalize' do
    it 'returns nil when temperature is nil' do
      expect(described_class.normalize(nil)).to be_nil
    end

    it 'passes through valid temperature values' do
      expect(described_class.normalize(0.5)).to eq(0.5)
    end

    it 'accepts temperature 0.0' do
      expect(described_class.normalize(0.0)).to eq(0.0)
    end

    it 'accepts temperature 1.0' do
      expect(described_class.normalize(1.0)).to eq(1.0)
    end

    it 'clamps temperature above 1.0 to 1.0' do
      expect(described_class.normalize(1.5)).to eq(1.0)
    end

    it 'clamps temperature below 0.0 to 0.0' do
      expect(described_class.normalize(-0.5)).to eq(0.0)
    end

    it 'clamps temperature 2.0 to 1.0' do
      expect(described_class.normalize(2.0)).to eq(1.0)
    end
  end
end
