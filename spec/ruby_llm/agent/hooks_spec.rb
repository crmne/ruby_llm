# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent'

RSpec.describe RubyLLM::Agent::Hooks do
  let(:hooks) { described_class.new }

  describe '#add' do
    it 'adds hooks for before phase' do
      called = false
      hooks.add(:before, 'Bash') { called = true }

      context = RubyLLM::Agent::HookContext.new(
        tool_name: 'Bash',
        arguments: {},
        phase: :before
      )
      hooks.run(:before, context)

      expect(called).to be true
    end

    it 'adds hooks for after phase' do
      called = false
      hooks.add(:after, 'Read') { called = true }

      context = RubyLLM::Agent::HookContext.new(
        tool_name: 'Read',
        arguments: {},
        phase: :after
      )
      hooks.run(:after, context)

      expect(called).to be true
    end
  end

  describe '#run' do
    it 'matches hooks by string pattern' do
      called = false
      hooks.add(:before, 'Bash') { called = true }

      context = RubyLLM::Agent::HookContext.new(tool_name: 'Bash', arguments: {}, phase: :before)
      hooks.run(:before, context)
      expect(called).to be true
    end

    it 'matches hooks by regex pattern' do
      called = false
      hooks.add(:before, /^Ba/) { called = true }

      context = RubyLLM::Agent::HookContext.new(tool_name: 'Bash', arguments: {}, phase: :before)
      hooks.run(:before, context)
      expect(called).to be true
    end

    it 'matches hooks by nil pattern (all tools)' do
      called = false
      hooks.add(:before, nil) { called = true }

      context = RubyLLM::Agent::HookContext.new(tool_name: 'AnyTool', arguments: {}, phase: :before)
      hooks.run(:before, context)
      expect(called).to be true
    end

    it 'skips non-matching hooks' do
      called = false
      hooks.add(:before, 'Read') { called = true }

      context = RubyLLM::Agent::HookContext.new(tool_name: 'Bash', arguments: {}, phase: :before)
      hooks.run(:before, context)
      expect(called).to be false
    end

    it 'stops on block!' do
      call_order = []
      hooks.add(:before, nil) { |ctx| call_order << 1; ctx.block! }
      hooks.add(:before, nil) { call_order << 2 }

      context = RubyLLM::Agent::HookContext.new(tool_name: 'Test', arguments: {}, phase: :before)
      hooks.run(:before, context)

      expect(call_order).to eq([1])
      expect(context.blocked?).to be true
    end
  end
end

RSpec.describe RubyLLM::Agent::HookContext do
  let(:context) do
    described_class.new(
      tool_name: 'Bash',
      arguments: { command: 'ls' },
      phase: :before
    )
  end

  describe '#block!' do
    it 'marks context as blocked' do
      expect(context.blocked?).to be false
      context.block!
      expect(context.blocked?).to be true
    end
  end

  describe '#modify_arguments' do
    it 'updates arguments' do
      context.modify_arguments({ command: 'pwd' })
      expect(context.arguments[:command]).to eq('pwd')
    end
  end
end
