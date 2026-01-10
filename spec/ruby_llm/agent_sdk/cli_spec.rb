# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::CLI do
  describe '#initialize' do
    it 'accepts options hash' do
      cli = described_class.new(cwd: '/tmp', max_turns: 5)
      expect(cli).to be_a(described_class)
    end

    it 'accepts cli_path option' do
      cli = described_class.new(cli_path: '/custom/claude')
      expect(cli.instance_variable_get(:@cli_path)).to eq('/custom/claude')
    end

    it 'defaults cli_path to COMMAND constant' do
      cli = described_class.new
      expect(cli.instance_variable_get(:@cli_path)).to eq(described_class::COMMAND)
    end
  end

  describe '#build_args' do
    let(:cli) { described_class.new(options) }

    context 'with fork_session option' do
      let(:options) { { fork_session: true, resume: 'session-123' } }

      it 'includes --fork-session flag' do
        args = cli.send(:build_args, 'test prompt')
        expect(args).to include('--fork-session')
      end
    end

    context 'without fork_session' do
      let(:options) { { resume: 'session-123' } }

      it 'does not include --fork-session flag' do
        args = cli.send(:build_args, 'test prompt')
        expect(args).not_to include('--fork-session')
      end
    end

    context 'with all options' do
      let(:options) do
        {
          cwd: '/tmp',
          model: 'claude-sonnet',
          max_turns: 5,
          permission_mode: :bypass_permissions,
          resume: 'session-123',
          system_prompt: 'Be helpful',
          allowed_tools: %w[Read Write],
          disallowed_tools: %w[Bash],
          fork_session: true
        }
      end

      it 'builds complete argument list' do
        args = cli.send(:build_args, 'test prompt')

        expect(args).to include('--cwd', '/tmp')
        expect(args).to include('--model', 'claude-sonnet')
        expect(args).to include('--max-turns', '5')
        expect(args).to include('--permission-mode', 'bypassPermissions')
        expect(args).to include('--resume', 'session-123')
        expect(args).to include('--system-prompt', 'Be helpful')
        expect(args).to include('--allowed-tool', 'Read')
        expect(args).to include('--allowed-tool', 'Write')
        expect(args).to include('--disallowed-tool', 'Bash')
        expect(args).to include('--fork-session')
        expect(args.last).to eq('test prompt')
      end
    end
  end

  describe 'custom CLI path' do
    it 'uses custom path when spawning process' do
      cli = described_class.new(cli_path: '/custom/claude')

      # The command used should be the custom path
      expect(cli.instance_variable_get(:@cli_path)).to eq('/custom/claude')
    end
  end
end
