# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Permissions do
  describe 'MODES' do
    it 'includes all official permission modes' do
      expect(described_class::MODES).to include(:default)
      expect(described_class::MODES).to include(:accept_edits)
      expect(described_class::MODES).to include(:dont_ask)
      expect(described_class::MODES).to include(:bypass_permissions)
      expect(described_class::MODES).to include(:plan)
      expect(described_class::MODES).to include(:delegate)
    end
  end

  describe '.valid?' do
    it 'returns true for valid modes' do
      expect(described_class.valid?(:default)).to be true
      expect(described_class.valid?(:delegate)).to be true
      expect(described_class.valid?(:bypass_permissions)).to be true
    end

    it 'returns false for invalid modes' do
      expect(described_class.valid?(:invalid_mode)).to be false
    end
  end

  describe '.to_cli_format' do
    it 'converts Ruby symbols to CLI camelCase' do
      expect(described_class.to_cli_format(:default)).to eq('default')
      expect(described_class.to_cli_format(:accept_edits)).to eq('acceptEdits')
      expect(described_class.to_cli_format(:dont_ask)).to eq('dontAsk')
      expect(described_class.to_cli_format(:bypass_permissions)).to eq('bypassPermissions')
      expect(described_class.to_cli_format(:plan)).to eq('plan')
      expect(described_class.to_cli_format(:delegate)).to eq('delegate')
    end
  end

  describe '.auto_approve?' do
    context 'with delegate mode' do
      it 'returns nil to defer to callback' do
        result = described_class.auto_approve?(:delegate, 'Bash', { command: 'ls' })
        expect(result).to be_nil
      end
    end
  end
end
