# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Permissions do
  describe 'constants' do
    it 'defines permission modes' do
      expect(described_class::DEFAULT).to eq(:default)
      expect(described_class::ACCEPT_EDITS).to eq(:accept_edits)
      expect(described_class::BYPASS).to eq(:bypass_permissions)
      expect(described_class::PLAN).to eq(:plan)
    end

    it 'lists all valid modes' do
      expect(described_class::MODES).to include(:default, :accept_edits, :bypass_permissions, :plan)
    end
  end

  describe '.valid?' do
    it 'returns true for valid modes' do
      described_class::MODES.each do |mode|
        expect(described_class.valid?(mode)).to be true
      end
    end

    it 'returns false for invalid modes' do
      expect(described_class.valid?(:invalid)).to be false
    end

    it 'accepts string modes' do
      expect(described_class.valid?('default')).to be true
    end
  end

  describe '.auto_approve?' do
    context 'with bypass_permissions mode' do
      it 'returns true for all tools' do
        expect(described_class.auto_approve?(:bypass_permissions, 'Bash')).to be true
        expect(described_class.auto_approve?(:bypass_permissions, 'Read')).to be true
      end
    end

    context 'with accept_edits mode' do
      it 'returns true for Edit tool' do
        expect(described_class.auto_approve?(:accept_edits, 'Edit')).to be true
      end

      it 'returns true for Write tool' do
        expect(described_class.auto_approve?(:accept_edits, 'Write')).to be true
      end

      it 'returns true for allowed Bash commands' do
        %w[mkdir touch rm mv cp].each do |cmd|
          expect(described_class.auto_approve?(:accept_edits, 'Bash', { command: cmd })).to be true
        end
      end

      it 'returns nil for non-allowed Bash commands' do
        expect(described_class.auto_approve?(:accept_edits, 'Bash', { command: 'git push' })).to be_nil
      end

      it 'returns nil for other tools' do
        expect(described_class.auto_approve?(:accept_edits, 'WebSearch')).to be_nil
      end
    end

    context 'with plan mode' do
      it 'returns false for all tools' do
        expect(described_class.auto_approve?(:plan, 'Read')).to be false
        expect(described_class.auto_approve?(:plan, 'Bash')).to be false
      end
    end

    context 'with default mode' do
      it 'returns nil for all tools' do
        expect(described_class.auto_approve?(:default, 'Read')).to be_nil
        expect(described_class.auto_approve?(:default, 'Bash')).to be_nil
      end
    end
  end

  describe RubyLLM::AgentSDK::Permissions::Result do
    describe '.allow' do
      it 'creates allow result' do
        result = described_class.allow
        expect(result.allow?).to be true
        expect(result.deny?).to be false
      end

      it 'accepts updated input' do
        result = described_class.allow({ sanitized: true })
        expect(result.updated_input).to eq({ sanitized: true })
      end
    end

    describe '.deny' do
      it 'creates deny result' do
        result = described_class.deny('security violation')
        expect(result.deny?).to be true
        expect(result.allow?).to be false
        expect(result.message).to eq('security violation')
      end
    end

    describe '.ask' do
      it 'creates ask result' do
        result = described_class.ask
        expect(result.ask?).to be true
      end
    end
  end
end
