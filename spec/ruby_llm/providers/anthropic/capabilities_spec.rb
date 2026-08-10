# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Capabilities do
  describe '.critical_capabilities_for' do
    it 'claims citations for the models that support them' do
      expect(described_class.critical_capabilities_for('claude-haiku-4-5')).to eq(
        %w[citations tool_choice parallel_tool_calls]
      )
    end

    it 'drops citations for Haiku 3' do
      expect(described_class.critical_capabilities_for('claude-3-haiku-20240307')).to eq(
        %w[tool_choice parallel_tool_calls]
      )
    end
  end
end
