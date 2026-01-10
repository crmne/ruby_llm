# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Hooks do
  describe 'EVENTS' do
    it 'includes all official hook events' do
      expect(described_class::EVENTS).to include(
        :pre_tool_use,
        :post_tool_use,
        :post_tool_use_failure,
        :stop,
        :subagent_start,
        :subagent_stop,
        :session_start,
        :session_end,
        :user_prompt_submit,
        :pre_compact,
        :notification,
        :permission_request
      )
    end
  end

  describe 'PERMISSION_DECISIONS' do
    it 'includes all permission decisions' do
      expect(described_class::PERMISSION_DECISIONS).to eq([:allow, :deny, :ask])
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Result do
    describe '.approve' do
      it 'creates approved result' do
        result = described_class.approve({ command: 'ls' })
        expect(result.decision).to eq(:approve)
        expect(result.payload).to eq({ command: 'ls' })
        expect(result.continue).to be true
      end
    end

    describe '.block' do
      it 'creates blocked result with reason' do
        result = described_class.block('Not allowed')
        expect(result.decision).to eq(:block)
        expect(result.reason).to eq('Not allowed')
      end
    end

    describe '.modify' do
      it 'creates modified result with new payload' do
        result = described_class.modify({ command: 'ls -la' })
        expect(result.decision).to eq(:modify)
        expect(result.payload).to eq({ command: 'ls -la' })
      end
    end

    describe 'advanced output fields' do
      it 'supports additional_context' do
        result = described_class.new(
          decision: :approve,
          additional_context: 'Extra info',
          continue: true
        )
        expect(result.additional_context).to eq('Extra info')
      end

      it 'supports system_message' do
        result = described_class.new(
          decision: :approve,
          system_message: 'System notice',
          continue: true
        )
        expect(result.system_message).to eq('System notice')
      end

      it 'supports continue flag' do
        result = described_class.new(decision: :approve, continue: false)
        expect(result.continue).to be false
      end

      it 'supports suppress_output' do
        result = described_class.suppress
        expect(result.suppress_output).to be true
      end

      it 'supports async flag' do
        result = described_class.async(timeout: 30)
        expect(result.async).to be true
        expect(result.async_timeout).to eq(30)
        expect(result.async?).to be true
      end
    end

    describe '.stop' do
      it 'creates result that stops agent' do
        result = described_class.stop('Task completed')
        expect(result.decision).to eq(:approve)
        expect(result.continue).to be false
        expect(result.stop_reason).to eq('Task completed')
      end
    end

    describe '.with_context' do
      it 'creates result with additional context' do
        result = described_class.with_context('Additional info')
        expect(result.decision).to eq(:approve)
        expect(result.additional_context).to eq('Additional info')
        expect(result.continue).to be true
      end
    end

    describe '.with_system_message' do
      it 'creates result with system message' do
        result = described_class.with_system_message('Important notice')
        expect(result.decision).to eq(:approve)
        expect(result.system_message).to eq('Important notice')
        expect(result.continue).to be true
      end
    end

    describe '.permission' do
      it 'creates result with permission decision' do
        result = described_class.permission(:allow, reason: 'Auto-approved', updated_input: { cmd: 'ls' })
        expect(result.hook_specific_output[:hook_event_name]).to eq(:pre_tool_use)
        expect(result.hook_specific_output[:permission_decision]).to eq(:allow)
        expect(result.hook_specific_output[:permission_decision_reason]).to eq('Auto-approved')
        expect(result.hook_specific_output[:updated_input]).to eq({ cmd: 'ls' })
      end
    end
  end

  # Hook Input Types
  describe 'Hook Input Types' do
    describe RubyLLM::AgentSDK::Hooks::PreToolUseInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          transcript_path: '/tmp/transcript.json',
          cwd: '/home/user',
          permission_mode: 'default',
          tool_name: 'Bash',
          tool_input: { command: 'ls' }
        )
        expect(input.hook_event_name).to eq(:pre_tool_use)
        expect(input.tool_name).to eq('Bash')
        expect(input.tool_input).to eq({ command: 'ls' })
      end
    end

    describe RubyLLM::AgentSDK::Hooks::PostToolUseInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          tool_name: 'Bash',
          tool_input: { command: 'ls' },
          tool_response: 'file1.txt\nfile2.txt'
        )
        expect(input.hook_event_name).to eq(:post_tool_use)
        expect(input.tool_response).to eq('file1.txt\nfile2.txt')
      end
    end

    describe RubyLLM::AgentSDK::Hooks::PostToolUseFailureInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          tool_name: 'Bash',
          tool_input: { command: 'rm -rf /' },
          error: 'Permission denied',
          is_interrupt: true
        )
        expect(input.hook_event_name).to eq(:post_tool_use_failure)
        expect(input.error).to eq('Permission denied')
        expect(input.is_interrupt).to be true
      end
    end

    describe RubyLLM::AgentSDK::Hooks::SubagentStartInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          agent_id: 'agent-456',
          agent_type: 'researcher'
        )
        expect(input.hook_event_name).to eq(:subagent_start)
        expect(input.agent_id).to eq('agent-456')
        expect(input.agent_type).to eq('researcher')
      end
    end

    describe RubyLLM::AgentSDK::Hooks::SessionStartInput do
      it 'has correct structure with source' do
        input = described_class.new(
          session_id: 'sess-123',
          source: 'startup'
        )
        expect(input.hook_event_name).to eq(:session_start)
        expect(input.source).to eq('startup')
      end
    end

    describe RubyLLM::AgentSDK::Hooks::SessionEndInput do
      it 'has correct structure with reason' do
        input = described_class.new(
          session_id: 'sess-123',
          reason: 'user_exit'
        )
        expect(input.hook_event_name).to eq(:session_end)
        expect(input.reason).to eq('user_exit')
      end
    end

    describe RubyLLM::AgentSDK::Hooks::PreCompactInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          trigger: 'auto',
          custom_instructions: 'Keep recent context'
        )
        expect(input.hook_event_name).to eq(:pre_compact)
        expect(input.trigger).to eq('auto')
        expect(input.custom_instructions).to eq('Keep recent context')
      end
    end

    describe RubyLLM::AgentSDK::Hooks::PermissionRequestInput do
      it 'has correct structure' do
        input = described_class.new(
          session_id: 'sess-123',
          tool_name: 'Write',
          tool_input: { file_path: '/etc/hosts' },
          permission_suggestions: [{ type: 'addRules', rules: [] }]
        )
        expect(input.hook_event_name).to eq(:permission_request)
        expect(input.permission_suggestions).to be_a(Array)
      end
    end
  end

  describe 'INPUT_TYPES' do
    it 'maps all events to input types' do
      expect(described_class::INPUT_TYPES.keys).to eq(described_class::EVENTS)
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Matcher do
    describe '#initialize' do
      it 'accepts pattern and handlers' do
        matcher = described_class.new(pattern: /^mcp__/, handlers: [])
        expect(matcher.pattern).to be_a(Regexp)
      end

      it 'accepts timeout option' do
        matcher = described_class.new(timeout: 30)
        expect(matcher.timeout).to eq(30)
      end

      it 'defaults timeout to 60 seconds' do
        matcher = described_class.new
        expect(matcher.timeout).to eq(60)
      end
    end

    describe '#matches?' do
      it 'matches exact tool name' do
        matcher = described_class.new(pattern: 'Bash')
        expect(matcher.matches?('Bash')).to be true
        expect(matcher.matches?('Read')).to be false
      end

      it 'matches regex pattern' do
        matcher = described_class.new(pattern: /^mcp__/)
        expect(matcher.matches?('mcp__server__tool')).to be true
        expect(matcher.matches?('Bash')).to be false
      end

      it 'matches MCP tool patterns' do
        matcher = described_class.new(pattern: /^mcp__/)
        expect(matcher.matches?('mcp__filesystem__read')).to be true
      end

      it 'matches all when pattern is nil' do
        matcher = described_class.new(pattern: nil)
        expect(matcher.matches?('Bash')).to be true
        expect(matcher.matches?('Read')).to be true
      end

      it 'matches array of tool names' do
        matcher = described_class.new(pattern: ['Bash', 'Read', 'Write'])
        expect(matcher.matches?('Bash')).to be true
        expect(matcher.matches?('Grep')).to be false
      end

      it 'matches with proc' do
        matcher = described_class.new(pattern: ->(name) { name.start_with?('mcp__') })
        expect(matcher.matches?('mcp__server__tool')).to be true
        expect(matcher.matches?('Bash')).to be false
      end
    end
  end

  describe RubyLLM::AgentSDK::Hooks::CallbackMatcher do
    it 'stores matcher and hooks' do
      hooks = [->(_ctx) { true }]
      cb_matcher = described_class.new(matcher: 'Bash', hooks: hooks)
      expect(cb_matcher.matcher).to eq('Bash')
      expect(cb_matcher.hooks).to eq(hooks)
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Runner do
    let(:runner) { described_class.new(hooks) }

    describe 'with no hooks' do
      let(:hooks) { {} }

      it 'approves by default' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.decision).to eq(:approve)
      end
    end

    describe 'with blocking hook' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.block('Blocked') } }
          ]
        }
      end

      it 'blocks the operation' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(result.blocked?).to be true
        expect(result.reason).to eq('Blocked')
      end
    end

    describe 'with modifying hook' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(ctx) { RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(extra: true)) } }
          ]
        }
      end

      it 'modifies the input' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.payload[:extra]).to be true
        expect(result.payload[:command]).to eq('ls')
      end
    end

    describe 'with hook that adds context' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.with_context('Extra info') } }
          ]
        }
      end

      it 'includes additional context in result' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(result.additional_context).to eq('Extra info')
      end
    end

    describe 'with hook that injects system message' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.with_system_message('Notice') } }
          ]
        }
      end

      it 'includes system message in result' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(result.system_message).to eq('Notice')
      end
    end

    describe 'with hook timeout' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(_ctx) { sleep 2 }, timeout: 0.1 }
          ]
        }
      end

      it 'times out and blocks by default (fail-closed)' do
        expect { runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' }) }
          .to output(/Hook failed/).to_stderr
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.blocked?).to be true
        expect(result.reason).to eq('Hook timed out')
      end

      context 'with fail_mode: :open' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { sleep 2 }, timeout: 0.1, fail_mode: :open }
            ]
          }
        end

        it 'times out and approves (backwards compatible)' do
          result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
          expect(result.approved?).to be true
        end
      end
    end

    describe 'fail-closed security behavior' do
      describe 'when hook raises StandardError' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { raise 'Unexpected error' } }
            ]
          }
        end

        it 'blocks the operation (fail-closed)' do
          result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
          expect(result.blocked?).to be true
          expect(result.reason).to match(/Hook failed: RuntimeError/)
        end

        it 'logs the error' do
          expect { runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' }) }
            .to output(/Hook failed.*RuntimeError.*Unexpected error/).to_stderr
        end
      end

      describe 'when hook raises ArgumentError' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { raise ArgumentError, 'bad argument' } }
            ]
          }
        end

        it 'blocks the operation with error class in reason' do
          result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
          expect(result.blocked?).to be true
          expect(result.reason).to eq('Hook failed: ArgumentError')
        end
      end

      describe 'with fail_mode: :open (backwards compatibility)' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { raise 'Error' }, fail_mode: :open }
            ]
          }
        end

        it 'approves despite error (insecure but backwards compatible)' do
          result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
          expect(result.approved?).to be true
        end
      end

      describe 'runner-level fail_mode configuration' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { raise 'Error' } }
            ]
          }
        end

        context 'with fail_mode: :open on runner' do
          let(:runner) { described_class.new(hooks, fail_mode: :open) }

          it 'approves on error' do
            result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
            expect(result.approved?).to be true
          end
        end

        context 'hook fail_mode overrides runner fail_mode' do
          let(:hooks) do
            {
              pre_tool_use: [
                { handler: ->(_ctx) { raise 'Error' }, fail_mode: :closed }
              ]
            }
          end
          let(:runner) { described_class.new(hooks, fail_mode: :open) }

          it 'blocks because hook specifies :closed' do
            result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
            expect(result.blocked?).to be true
          end
        end
      end

      describe 'custom logger' do
        let(:hooks) do
          {
            pre_tool_use: [
              { handler: ->(_ctx) { raise 'Test error' } }
            ]
          }
        end
        let(:logger) { double('Logger') }

        before do
          RubyLLM::AgentSDK::Hooks.logger = logger
        end

        after do
          RubyLLM::AgentSDK::Hooks.logger = nil
        end

        it 'logs to custom logger when configured' do
          expect(logger).to receive(:warn).with(/Hook failed.*RuntimeError.*Test error/)
          runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        end
      end
    end

    describe 'with multiple hooks' do
      let(:hooks) do
        {
          pre_tool_use: [
            { handler: ->(ctx) { RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(first: true)) } },
            { handler: ->(ctx) { RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(second: true)) } }
          ]
        }
      end

      it 'chains modifications' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { command: 'ls' })
        expect(result.payload[:first]).to be true
        expect(result.payload[:second]).to be true
      end
    end

    describe 'with matcher filtering' do
      let(:hooks) do
        {
          pre_tool_use: [
            { matcher: 'Read', handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.block('Read blocked') } }
          ]
        }
      end

      it 'only runs matching hooks' do
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: {})
        expect(result.approved?).to be true

        result = runner.run(:pre_tool_use, tool_name: 'Read', tool_input: {})
        expect(result.blocked?).to be true
      end
    end
  end
end
