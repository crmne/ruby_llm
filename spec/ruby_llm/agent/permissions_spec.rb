# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent'

RSpec.describe RubyLLM::Agent::Permissions do
  let(:permissions) { described_class.new }

  describe '#mode' do
    it 'defaults to allow_all' do
      expect(permissions.mode).to eq(:allow_all)
    end

    it 'can be set' do
      permissions.mode = :deny_all
      expect(permissions.mode).to eq(:deny_all)
    end
  end

  describe '#allowed?' do
    context 'with allow_all mode' do
      it 'allows all tools' do
        permissions.mode = :allow_all
        expect(permissions.allowed?('Bash')).to be true
        expect(permissions.allowed?('Read')).to be true
      end
    end

    context 'with deny_all mode' do
      it 'denies all tools' do
        permissions.mode = :deny_all
        expect(permissions.allowed?('Bash')).to be false
        expect(permissions.denial_reason).to include('deny_all')
      end
    end

    context 'with allow_list mode' do
      before do
        permissions.mode = :allow_list
        permissions.allow('Read', 'Grep')
      end

      it 'allows listed tools' do
        expect(permissions.allowed?('Read')).to be true
      end

      it 'denies unlisted tools' do
        expect(permissions.allowed?('Bash')).to be false
        expect(permissions.denial_reason).to include('not in allow list')
      end
    end

    context 'with deny_list mode' do
      before do
        permissions.mode = :deny_list
        permissions.deny('Bash')
      end

      it 'denies listed tools' do
        expect(permissions.allowed?('Bash')).to be false
      end

      it 'allows unlisted tools' do
        expect(permissions.allowed?('Read')).to be true
      end
    end

    context 'with explicit deny' do
      it 'denies even in allow_all mode' do
        permissions.mode = :allow_all
        permissions.deny('Bash')

        expect(permissions.allowed?('Bash')).to be false
        expect(permissions.denial_reason).to include('explicitly denied')
      end
    end

    context 'with custom callback' do
      it 'uses callback to determine permission' do
        permissions.on('Bash') { |args| !args[:command]&.include?('rm') }

        expect(permissions.allowed?('Bash', { command: 'ls' })).to be true
        expect(permissions.allowed?('Bash', { command: 'rm file' })).to be false
      end
    end
  end

  describe '#allow' do
    it 'returns self for chaining' do
      expect(permissions.allow('Read')).to eq(permissions)
    end
  end

  describe '#deny' do
    it 'returns self for chaining' do
      expect(permissions.deny('Bash')).to eq(permissions)
    end
  end
end
