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
      expect(options.hooks).to eq({})
      expect(options.additional_directories).to eq([])
      expect(options.betas).to eq([])
      expect(options.plugins).to eq([])
      expect(options.agents).to eq({})
      expect(options.setting_sources).to eq([])
    end

    it 'accepts all configuration options' do
      options = described_class.new(
        prompt: 'test',
        model: 'claude-sonnet',
        max_turns: 5,
        permission_mode: :bypass_permissions
      )
      expect(options.prompt).to eq('test')
      expect(options.model).to eq('claude-sonnet')
      expect(options.max_turns).to eq(5)
      expect(options.permission_mode).to eq(:bypass_permissions)
    end
  end

  describe '#cli_path' do
    it 'defaults to nil (uses system claude)' do
      options = described_class.new
      expect(options.cli_path).to be_nil
    end

    it 'can be set to custom path' do
      options = described_class.new(cli_path: '/custom/path/claude')
      expect(options.cli_path).to eq('/custom/path/claude')
    end
  end

  describe '#with_cli_path' do
    it 'sets custom CLI path and returns self' do
      options = described_class.new
      result = options.with_cli_path('/custom/claude')
      expect(result).to be(options)
      expect(options.cli_path).to include('custom/claude')
    end

    it 'expands relative paths' do
      options = described_class.new.with_cli_path('~/bin/claude')
      expect(options.cli_path).not_to include('~')
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
      expect(result).to be(options)
      expect(options.fork_session).to be true
    end

    it 'can be disabled explicitly' do
      options = described_class.new.with_fork_session(false)
      expect(options.fork_session).to be false
    end
  end

  # New SDK parity tests
  describe 'model configuration' do
    it 'supports fallback_model' do
      options = described_class.new.with_fallback_model('claude-haiku')
      expect(options.fallback_model).to eq('claude-haiku')
    end

    it 'supports max_thinking_tokens' do
      options = described_class.new.with_max_thinking_tokens(1000)
      expect(options.max_thinking_tokens).to eq(1000)
    end

    it 'supports max_budget_usd' do
      options = described_class.new.with_max_budget_usd(5.0)
      expect(options.max_budget_usd).to eq(5.0)
    end
  end

  describe 'permission & security' do
    it 'supports allow_dangerously_skip_permissions' do
      options = described_class.new.with_dangerous_permissions
      expect(options.allow_dangerously_skip_permissions).to be true
    end
  end

  describe 'session management' do
    it 'supports continue option' do
      options = described_class.new.with_continue
      expect(options.continue).to be true
    end

    it 'supports resume with resume_session_at' do
      options = described_class.new.with_resume('session-123', at: 'message-456')
      expect(options.resume).to eq('session-123')
      expect(options.resume_session_at).to eq('message-456')
    end
  end

  describe 'directories & settings' do
    it 'supports additional_directories' do
      options = described_class.new.with_additional_directories('/tmp', '/var')
      expect(options.additional_directories.size).to eq(2)
    end

    it 'supports setting_sources' do
      options = described_class.new.with_setting_sources(:user, :project, :local)
      expect(options.setting_sources).to eq([:user, :project, :local])
    end
  end

  describe 'streaming & output' do
    it 'supports include_partial_messages' do
      options = described_class.new.with_partial_messages
      expect(options.include_partial_messages).to be true
    end

    it 'supports output_format with JSON schema' do
      schema = { type: 'object', properties: { name: { type: 'string' } } }
      options = described_class.new.with_output_format(schema)
      expect(options.output_format[:type]).to eq('json_schema')
      expect(options.output_format[:schema]).to eq(schema)
    end

    it 'supports stderr callback' do
      callback = ->(msg) { puts msg }
      options = described_class.new.with_stderr(&callback)
      expect(options.stderr).to eq(callback)
    end
  end

  describe 'advanced options' do
    it 'supports agents (subagent definitions)' do
      agents = {
        researcher: {
          description: 'Research agent',
          prompt: 'You are a researcher',
          tools: ['Read', 'Grep']
        }
      }
      options = described_class.new.with_agents(agents)
      expect(options.agents).to eq(agents)
    end

    it 'supports plugins' do
      plugins = [{ type: 'local', path: './my-plugin' }]
      options = described_class.new.with_plugins(plugins)
      expect(options.plugins).to eq(plugins)
    end

    it 'supports betas' do
      options = described_class.new.with_betas('context-1m-2025-08-07')
      expect(options.betas).to eq(['context-1m-2025-08-07'])
    end

    it 'supports sandbox configuration' do
      sandbox = { enabled: true, auto_allow_bash_if_sandboxed: true }
      options = described_class.new.with_sandbox(sandbox)
      expect(options.sandbox).to eq(sandbox)
    end

    it 'supports file checkpointing' do
      options = described_class.new.with_file_checkpointing
      expect(options.enable_file_checkpointing).to be true
    end
  end

  describe '#to_cli_args' do
    it 'includes all new options' do
      options = described_class.new(
        model: 'claude-sonnet',
        fallback_model: 'claude-haiku',
        max_turns: 5,
        max_thinking_tokens: 1000,
        max_budget_usd: 5.0,
        continue: true,
        include_partial_messages: true,
        enable_file_checkpointing: true,
        betas: ['context-1m-2025-08-07']
      )

      args = options.to_cli_args

      expect(args[:model]).to eq('claude-sonnet')
      expect(args[:fallback_model]).to eq('claude-haiku')
      expect(args[:max_turns]).to eq(5)
      expect(args[:max_thinking_tokens]).to eq(1000)
      expect(args[:max_budget_usd]).to eq(5.0)
      expect(args[:continue]).to be true
      expect(args[:include_partial_messages]).to be true
      expect(args[:enable_file_checkpointing]).to be true
      expect(args[:betas]).to eq(['context-1m-2025-08-07'])
    end
  end

  describe '.schema' do
    it 'exposes all option definitions for introspection' do
      schema = described_class.schema
      expect(schema).to include(:prompt, :model, :max_turns, :permission_mode)
      expect(schema).to include(:fallback_model, :max_thinking_tokens, :max_budget_usd)
      expect(schema).to include(:agents, :plugins, :betas, :sandbox)
    end
  end
end
