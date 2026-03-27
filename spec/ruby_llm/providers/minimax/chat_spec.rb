# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax::Chat do
  describe '.format_role' do
    it 'converts symbol roles to strings' do
      expect(described_class.format_role(:user)).to eq('user')
    end

    it 'passes through string roles' do
      expect(described_class.format_role('assistant')).to eq('assistant')
    end

    it 'converts system role to string' do
      expect(described_class.format_role(:system)).to eq('system')
    end
  end
end
