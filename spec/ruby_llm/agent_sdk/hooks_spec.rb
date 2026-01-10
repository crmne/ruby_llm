# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Hooks do
  describe 'EVENTS' do
    it 'contains all hook events' do
      expect(described_class::EVENTS).to include(
        :pre_tool_use,
        :post_tool_use,
        :stop,
        :session_start,
        :session_end
      )
    end
  end

  describe 'DECISIONS' do
    it 'contains all decision types' do
      expect(described_class::DECISIONS).to eq(%i[approve block modify skip])
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Result do
    describe '.approve' do
      it 'creates approve result' do
        result = described_class.approve
        expect(result.approved?).to be true
        expect(result.blocked?).to be false
        expect(result.decision).to eq(:approve)
      end

      it 'accepts payload' do
        result = described_class.approve({ modified: true })
        expect(result.payload).to eq({ modified: true })
      end
    end

    describe '.block' do
      it 'creates block result with reason' do
        result = described_class.block('dangerous command')
        expect(result.blocked?).to be true
        expect(result.approved?).to be false
        expect(result.reason).to eq('dangerous command')
      end
    end

    describe '.modify' do
      it 'creates modify result with payload' do
        result = described_class.modify({ sanitized: true })
        expect(result.modified?).to be true
        expect(result.payload).to eq({ sanitized: true })
      end
    end

    describe '.skip' do
      it 'creates skip result' do
        result = described_class.skip
        expect(result.skipped?).to be true
      end
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Context do
    it 'provides access to tool info' do
      ctx = described_class.new(
        event: :pre_tool_use,
        tool_name: 'Bash',
        tool_input: { command: 'ls' },
        metadata: {}
      )
      expect(ctx.event).to eq(:pre_tool_use)
      expect(ctx.tool_name).to eq('Bash')
      expect(ctx.tool_input).to eq({ command: 'ls' })
    end

    it 'allows metadata access via []' do
      ctx = described_class.new(
        event: :pre_tool_use,
        tool_name: 'Bash',
        tool_input: {},
        metadata: { user_id: 123 }
      )
      expect(ctx[:user_id]).to eq(123)
    end

    it 'allows metadata assignment' do
      ctx = described_class.new(
        event: :pre_tool_use,
        tool_name: 'Bash',
        tool_input: {},
        metadata: {}
      )
      ctx[:processed] = true
      expect(ctx[:processed]).to be true
    end
  end

  describe RubyLLM::AgentSDK::Hooks::Runner do
    describe '#run' do
      it 'returns approve when no hooks defined' do
        runner = described_class.new({})
        result = runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(result.approved?).to be true
      end

      it 'executes matching hooks' do
        executed = false
        hooks = {
          pre_tool_use: [
            {
              matcher: 'Bash',
              handler: ->(_ctx) { executed = true; RubyLLM::AgentSDK::Hooks::Result.approve }
            }
          ]
        }
        runner = described_class.new(hooks)
        runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(executed).to be true
      end

      it 'skips non-matching hooks' do
        executed = false
        hooks = {
          pre_tool_use: [
            {
              matcher: 'Bash',
              handler: ->(_ctx) { executed = true; RubyLLM::AgentSDK::Hooks::Result.approve }
            }
          ]
        }
        runner = described_class.new(hooks)
        runner.run(:pre_tool_use, tool_name: 'Read')
        expect(executed).to be false
      end

      it 'stops on block result' do
        call_order = []
        hooks = {
          pre_tool_use: [
            {
              handler: ->(_ctx) { call_order << 1; RubyLLM::AgentSDK::Hooks::Result.block('blocked') }
            },
            {
              handler: ->(_ctx) { call_order << 2; RubyLLM::AgentSDK::Hooks::Result.approve }
            }
          ]
        }
        runner = described_class.new(hooks)
        result = runner.run(:pre_tool_use, tool_name: 'Bash')
        expect(result.blocked?).to be true
        expect(call_order).to eq([1])
      end

      it 'passes modified input through chain' do
        hooks = {
          pre_tool_use: [
            {
              handler: ->(ctx) { RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(step1: true)) }
            },
            {
              handler: ->(ctx) { RubyLLM::AgentSDK::Hooks::Result.modify(ctx.tool_input.merge(step2: true)) }
            }
          ]
        }
        runner = described_class.new(hooks)
        result = runner.run(:pre_tool_use, tool_name: 'Bash', tool_input: { original: true })
        expect(result.payload).to include(original: true, step1: true, step2: true)
      end

      context 'with regex matcher' do
        it 'matches tool names by pattern' do
          executed = false
          hooks = {
            pre_tool_use: [
              {
                matcher: /^Ba/,
                handler: ->(_ctx) { executed = true; RubyLLM::AgentSDK::Hooks::Result.approve }
              }
            ]
          }
          runner = described_class.new(hooks)
          runner.run(:pre_tool_use, tool_name: 'Bash')
          expect(executed).to be true
        end
      end

      context 'with array matcher' do
        it 'matches any tool in array' do
          executed = false
          hooks = {
            pre_tool_use: [
              {
                matcher: %w[Bash Read],
                handler: ->(_ctx) { executed = true; RubyLLM::AgentSDK::Hooks::Result.approve }
              }
            ]
          }
          runner = described_class.new(hooks)
          runner.run(:pre_tool_use, tool_name: 'Read')
          expect(executed).to be true
        end
      end

      context 'with proc matcher' do
        it 'uses proc for matching' do
          hooks = {
            pre_tool_use: [
              {
                matcher: ->(name) { name.start_with?('Web') },
                handler: ->(_ctx) { RubyLLM::AgentSDK::Hooks::Result.approve }
              }
            ]
          }
          runner = described_class.new(hooks)

          result1 = runner.run(:pre_tool_use, tool_name: 'WebFetch')
          result2 = runner.run(:pre_tool_use, tool_name: 'Bash')

          expect(result1.approved?).to be true
          expect(result2.approved?).to be true # No matching hook, defaults to approve
        end
      end
    end
  end
end
