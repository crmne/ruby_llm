# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Options do
  describe '#initialize' do
    it 'sets default values' do
      options = described_class.new

      expect(options.permission_mode).to eq(:default)
      expect(options.allowed_tools).to eq([])
      expect(options.disallowed_tools).to eq([])
      expect(options.mcp_servers).to eq({})
    end

    it 'accepts all configuration options' do
      options = described_class.new(
        system_prompt: 'Be helpful',
        max_turns: 5,
        allowed_tools: %w[Read Write],
        permission_mode: :bypass_permissions,
        cwd: '/tmp',
        model: :claude_sonnet,
        cli_path: '/custom/path/to/claude'
      )

      expect(options.system_prompt).to eq('Be helpful')
      expect(options.max_turns).to eq(5)
      expect(options.allowed_tools).to eq(%w[Read Write])
      expect(options.permission_mode).to eq(:bypass_permissions)
      expect(options.cwd).to eq('/tmp')
      expect(options.model).to eq(:claude_sonnet)
      expect(options.cli_path).to eq('/custom/path/to/claude')
    end
  end

  describe '#cli_path' do
    it 'defaults to nil (uses system claude)' do
      options = described_class.new
      expect(options.cli_path).to be_nil
    end

    it 'can be set to custom path' do
      options = described_class.new(cli_path: '/usr/local/bin/claude')
      expect(options.cli_path).to eq('/usr/local/bin/claude')
    end
  end

  describe '#with_cli_path' do
    it 'sets custom CLI path and returns self' do
      options = described_class.new
      result = options.with_cli_path('/custom/claude')

      expect(result).to eq(options)
      expect(options.cli_path).to eq('/custom/claude')
    end

    it 'expands relative paths' do
      options = described_class.new
      options.with_cli_path('~/bin/claude')

      expect(options.cli_path).to eq(File.expand_path('~/bin/claude'))
    end
  end

  describe '#to_cli_args' do
    it 'includes cli_path when set' do
      options = described_class.new(cli_path: '/custom/claude')
      args = options.to_cli_args

      expect(args[:cli_path]).to eq('/custom/claude')
    end
  end

  describe 'delegate permission mode' do
    it 'accepts delegate as valid permission mode' do
      options = described_class.new(permission_mode: :delegate)
      expect(options.permission_mode).to eq(:delegate)
    end
  end

  describe '#fork_session' do
    it 'defaults to false' do
      options = described_class.new
      expect(options.fork_session).to be false
    end

    it 'can be set to true' do
      options = described_class.new(fork_session: true)
      expect(options.fork_session).to be true
    end
  end

  describe '#with_fork_session' do
    it 'enables session forking and returns self' do
      options = described_class.new
      result = options.with_fork_session

      expect(result).to eq(options)
      expect(options.fork_session).to be true
    end

    it 'can be disabled explicitly' do
      options = described_class.new(fork_session: true)
      options.with_fork_session(false)

      expect(options.fork_session).to be false
    end
  end
end
