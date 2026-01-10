# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Hooks do
  describe 'EVENTS' do
    it 'includes all official hook events' do
      expect(described_class::EVENTS).to include(:pre_tool_use)
      expect(described_class::EVENTS).to include(:post_tool_use)
      expect(described_class::EVENTS).to include(:stop)
      expect(described_class::EVENTS).to include(:subagent_stop)
      expect(described_class::EVENTS).to include(:session_start)
      expect(described_class::EVENTS).to include(:session_end)
      expect(described_class::EVENTS).to include(:user_prompt_submit)
      expect(described_class::EVENTS).to include(:pre_compact)
      expect(described_class::EVENTS).to include(:notification)
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Result do
    describe '.approve' do
      it 'creates approved result' do
        result = described_class.approve({ command: 'ls' })
        expect(result.approved?).to be true
        expect(result.payload).to eq({ command: 'ls' })
      end
    end

    describe '.block' do
      it 'creates blocked result with reason' do
        result = described_class.block('Dangerous command')
        expect(result.blocked?).to be true
        expect(result.reason).to eq('Dangerous command')
      end
    end

    describe '.modify' do
      it 'creates modified result with new payload' do
        result = described_class.modify({ command: 'safe-ls' })
        expect(result.modified?).to be true
        expect(result.payload).to eq({ command: 'safe-ls' })
      end
    end

    describe 'advanced output fields' do
      it 'supports additional_context' do
        result = described_class.new(
          decision: :approve,
          additional_context: 'Extra context for Claude'
        )
        expect(result.additional_context).to eq('Extra context for Claude')
      end

      it 'supports system_message' do
        result = described_class.new(
          decision: :approve,
          system_message: 'Remember security best practices'
        )
        expect(result.system_message).to eq('Remember security best practices')
      end

      it 'supports continue flag' do
        result = described_class.new(
          decision: :approve,
          continue: false,
          stop_reason: 'Task completed'
        )
        expect(result.continue).to be false
        expect(result.stop_reason).to eq('Task completed')
      end
    end

    describe '.stop' do
      it 'creates result that stops agent' do
        result = described_class.stop('Task finished successfully')
        expect(result.continue).to be false
        expect(result.stop_reason).to eq('Task finished successfully')
      end
    end

    describe '.with_context' do
      it 'creates result with additional context' do
        result = described_class.with_context('Remember: use safe commands only')
        expect(result.approved?).to be true
        expect(result.additional_context).to eq('Remember: use safe commands only')
      end
    end

    describe '.with_system_message' do
      it 'creates result with system message' do
        result = described_class.with_system_message('Security reminder')
        expect(result.approved?).to be true
        expect(result.system_message).to eq('Security reminder')
      end
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Matcher do
    describe '#initialize' do
      it 'accepts pattern and handlers' do
        handler = ->(ctx) { true }
        matcher = described_class.new(pattern: 'Bash', handlers: [handler])

        expect(matcher.pattern).to eq('Bash')
        expect(matcher.handlers).to eq([handler])
      end

      it 'accepts timeout option' do
        matcher = described_class.new(pattern: 'Bash', handlers: [], timeout: 30)
        expect(matcher.timeout).to eq(30)
      end

      it 'defaults timeout to 60 seconds' do
        matcher = described_class.new(pattern: 'Bash', handlers: [])
        expect(matcher.timeout).to eq(60)
      end
    end

    describe '#matches?' do
      it 'matches exact tool name' do
        matcher = described_class.new(pattern: 'Bash', handlers: [])
        expect(matcher.matches?('Bash')).to be true
        expect(matcher.matches?('Read')).to be false
      end

      it 'matches regex pattern' do
        matcher = described_class.new(pattern: /Write|Edit/, handlers: [])
        expect(matcher.matches?('Write')).to be true
        expect(matcher.matches?('Edit')).to be true
        expect(matcher.matches?('Read')).to be false
      end

      it 'matches MCP tool patterns' do
        matcher = described_class.new(pattern: /^mcp__/, handlers: [])
        expect(matcher.matches?('mcp__playwright__click')).to be true
        expect(matcher.matches?('Bash')).to be false
      end

      it 'matches all when pattern is nil' do
        matcher = described_class.new(pattern: nil, handlers: [])
        expect(matcher.matches?('Bash')).to be true
        expect(matcher.matches?('Read')).to be true
      end
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Runner do
    let(:runner) { described_class.new(hooks) }

    context 'with no hooks' do
      let(:hooks) { {} }

      it 'approves by default' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.approved?).to be true
      end
    end

    context 'with blocking hook' do
      let(:hooks) do
        {
          pre_tool_use: [
            { matcher: 'Bash', handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.block('Blocked') } }
          ]
        }
      end

      it 'blocks the operation' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'rm -rf /' })
        expect(result.blocked?).to be true
        expect(result.reason).to eq('Blocked')
      end
    end

    context 'with modifying hook' do
      let(:hooks) do
        {
          pre_tool_use: [
            {
              matcher: 'Bash',
              handler: lambda { |ctx|
                RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(command: 'safe-ls'))
              }
            }
          ]
        }
      end

      it 'modifies the input' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.approved?).to be true
        expect(result.payload[:command]).to eq('safe-ls')
      end
    end

    context 'with hook that adds context' do
      let(:hooks) do
        {
          pre_tool_use: [
            {
              matcher: nil,
              handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.with_context('Be careful') }
            }
          ]
        }
      end

      it 'includes additional context in result' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: {})
        expect(result.additional_context).to eq('Be careful')
      end
    end

    context 'with hook that injects system message' do
      let(:hooks) do
        {
          pre_tool_use: [
            {
              matcher: nil,
              handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.with_system_message('Security!') }
            }
          ]
        }
      end

      it 'includes system message in result' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: {})
        expect(result.system_message).to eq('Security!')
      end
    end

    context 'with hook timeout' do
      let(:slow_handler) do
        lambda { |_ctx|
          sleep 0.2
          RubyLLM::AgentSDK::Hooks::Result.approve
        }
      end

      let(:hooks) do
        {
          pre_tool_use: [
            { matcher: nil, handler: slow_handler, timeout: 0.1 }
          ]
        }
      end

      it 'times out and approves by default' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: {})
        expect(result.approved?).to be true
      end
    end
  end
end
