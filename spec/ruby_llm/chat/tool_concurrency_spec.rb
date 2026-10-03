# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat::ToolConcurrency do
  let(:tool_calls) { { first: :first, second: :second } }
  let(:executor_calls) { Queue.new }
  let(:executor) do
    calls = executor_calls

    Object.new.tap do |object|
      object.define_singleton_method(:run!) do
        calls << :run
        Object.new.tap { |execution| execution.define_singleton_method(:complete!) { calls << :complete } }
      end
    end
  end

  def executor_events
    Array.new(executor_calls.size) { executor_calls.pop }.tally
  end

  def stub_rails_executor(executor)
    application = Object.new
    application.define_singleton_method(:executor) { executor }

    rails = Object.new
    rails.define_singleton_method(:application) { application }
    stub_const('Rails', rails)
  end

  it 'wraps threaded tool calls with the Rails executor' do
    stub_rails_executor(executor)

    results = described_class.run(:threads, tool_calls) { |tool_call| tool_call }

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_events).to eq(run: 2, complete: 2)
  end

  it 'reports threaded tool call results as they finish' do
    completed = []
    delayed_tool_calls = {
      slow: { label: :slow, delay: 0.05 },
      fast: { label: :fast, delay: 0.01 }
    }

    results = described_class.run(
      :threads,
      delayed_tool_calls,
      on_result: ->(tool_call, result) { completed << [tool_call[:label], result] }
    ) do |tool_call|
      sleep tool_call[:delay]
      tool_call[:label]
    end

    expect(completed).to eq([%i[fast fast], %i[slow slow]])
    expect(results).to eq([
                            [delayed_tool_calls[:slow], :slow],
                            [delayed_tool_calls[:fast], :fast]
                          ])
  end

  it 'propagates workflow context to threaded tool calls' do
    workflow_context = { workflow_id: 'workflow-1', workflow_step_id: 'step-1' }.freeze
    observed_contexts = Queue.new

    RubyLLM::Support::Instrumentation.with_workflow(workflow_context) do
      described_class.run(:threads, tool_calls) do
        observed_contexts << RubyLLM::Support::Instrumentation.current_workflow
      end
    end

    expect(Array.new(2) { observed_contexts.pop }).to all(eq(workflow_context))
  end

  def with_isolation(level)
    previous = ActiveSupport::IsolatedExecutionState.isolation_level
    ActiveSupport::IsolatedExecutionState.isolation_level = level
    yield
  ensure
    ActiveSupport::IsolatedExecutionState.isolation_level = previous
  end

  it 'wraps fiber tool calls with the Rails executor when each fiber has its own execution state' do
    stub_rails_executor(executor)

    results = with_isolation(:fiber) do
      in_reactor { described_class.run(:fibers, tool_calls) { |tool_call| tool_call } }
    end

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_events).to eq(run: 2, complete: 2)
  end

  it 'wraps the fiber that collects results outside a reactor when each fiber has its own execution state' do
    stub_rails_executor(executor)

    with_isolation(:fiber) { described_class.run(:fibers, tool_calls) { |tool_call| tool_call } }

    expect(executor_events).to eq(run: 3, complete: 3)
  end

  it 'runs fiber tool calls in the execution state they share with the caller' do
    stub_rails_executor(executor)

    results = with_isolation(:thread) { described_class.run(:fibers, tool_calls) { |tool_call| tool_call } }

    expect(results).to eq([%i[first first], %i[second second]])
    expect(executor_calls).to be_empty
  end

  it 'reports fiber tool call results in the calling fiber inside a reactor' do
    reporters = []
    on_result = ->(*) { reporters << Fiber.current }

    caller = in_reactor do
      described_class.run(:fibers, tool_calls, on_result:) { |tool_call| tool_call }
      Fiber.current
    end

    expect(reporters).to eq([caller, caller])
  end

  it 'reports fiber tool call results as they finish' do
    completed = []
    delayed_tool_calls = {
      slow: { label: :slow, delay: 0.05 },
      fast: { label: :fast, delay: 0.01 }
    }

    results = described_class.run(
      :fibers,
      delayed_tool_calls,
      on_result: ->(tool_call, result) { completed << [tool_call[:label], result] }
    ) do |tool_call|
      sleep tool_call[:delay]
      tool_call[:label]
    end

    expect(completed).to eq([%i[fast fast], %i[slow slow]])
    expect(results).to eq([
                            [delayed_tool_calls[:slow], :slow],
                            [delayed_tool_calls[:fast], :fast]
                          ])
  end

  it 'propagates workflow context to fiber tool calls' do
    workflow_context = { workflow_id: 'workflow-1', workflow_step_id: 'step-1' }.freeze
    observed_contexts = Queue.new

    RubyLLM::Support::Instrumentation.with_workflow(workflow_context) do
      described_class.run(:fibers, tool_calls) do
        observed_contexts << RubyLLM::Support::Instrumentation.current_workflow
      end
    end

    expect(Array.new(2) { observed_contexts.pop }).to all(eq(workflow_context))
  end

  it 'does nothing for an unknown concurrency mode' do
    expect(described_class.run(:processes, tool_calls) { |tool_call| tool_call }).to be_nil
  end

  it 'runs without a Rails executor' do
    stub_rails_executor(nil)

    expect(described_class.run(:threads, tool_calls) { |tool_call| tool_call }).to eq(
      [%i[first first], %i[second second]]
    )
  end

  it 'raises the first error a threaded tool call produced' do
    expect do
      described_class.run(:threads, tool_calls) { |_tool_call| raise ArgumentError, 'tool blew up' }
    end.to raise_error(ArgumentError, 'tool blew up')
  end

  it 'explains how to install async when the gem is missing' do
    allow(described_class).to receive(:require).with('async').and_raise(LoadError)

    expect { described_class.run(:fibers, tool_calls) { |tool_call| tool_call } }.to raise_error(
      LoadError, /The 'async' gem is required/
    )
  end

  it 'explains the minimum async version' do
    allow(Gem.loaded_specs.fetch('async')).to receive(:version).and_return(Gem::Version.new('1.15.5'))

    expect { described_class.run(:fibers, tool_calls) { |tool_call| tool_call } }.to raise_error(
      LoadError, /version 2.0 or newer/
    )
  end
end
