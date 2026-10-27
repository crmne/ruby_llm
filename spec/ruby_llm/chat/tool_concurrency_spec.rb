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

  def with_failing_context(error, after: false)
    subscriber = Object.new
    subscriber.define_singleton_method(:capture_context) { :snapshot }
    subscriber.define_singleton_method(:with_context) do |_, &block|
      block.call if after
      raise error
    end
    RubyLLM::Support::Instrumentation.subscribe(subscriber)
    yield
  ensure
    RubyLLM::Support::Instrumentation.unsubscribe(subscriber)
  end

  def error_without_watchdog(&block)
    expired = false
    watchdog = Class.new(StandardError) do
      define_method(:initialize) do |*arguments|
        expired = true
        super(*arguments)
      end
    end
    error = begin
      Timeout.timeout(1, watchdog, &block)
    rescue StandardError => e
      e
    end
    expect(expired).to be(false), 'result collection reached the watchdog'
    error
  end

  %i[threads fibers].each do |mode|
    it "preserves #{mode} tool values when a subscriber returns another value" do
      subscriber = Object.new
      subscriber.define_singleton_method(:capture_context) { :snapshot }
      subscriber.define_singleton_method(:with_context) do |_, &block|
        block.call
        :subscriber_result
      end
      RubyLLM::Support::Instrumentation.subscribe(subscriber)

      results = described_class.run(mode, tool_calls) { |call| call }

      expect(results).to eq([%i[first first], %i[second second]])
    ensure
      RubyLLM::Support::Instrumentation.unsubscribe(subscriber)
    end

    it "propagates #{mode} context setup failures before the watchdog" do
      failure = RuntimeError.new('context setup failed')
      executed = Queue.new
      with_failing_context(failure) do
        error = error_without_watchdog do
          described_class.run(mode, tool_calls) { executed << true }
        end
        expect(error).to equal(failure)
      end
      expect(executed).to be_empty
    end

    it "does not publish #{mode} successes when context teardown fails" do
      failure = RuntimeError.new('context teardown failed')
      reported = []
      with_failing_context(failure, after: true) do
        error = error_without_watchdog do
          described_class.run(mode, tool_calls, on_result: ->(*) { reported << true }) { :ok }
        end
        expect(error).to equal(failure)
      end
      expect(reported).to be_empty
    end

    it "propagates #{mode} workflow wrapper failures" do
      failure = RuntimeError.new('workflow setup failed')
      allow(RubyLLM::Support::Instrumentation).to receive(:with_workflow).and_raise(failure)

      error = error_without_watchdog { described_class.run(mode, tool_calls) { :ok } }

      expect(error).to equal(failure)
    end

    it "waits for remaining #{mode} workers when a result callback fails" do
      ready = Queue.new
      release = Queue.new
      finished = Queue.new
      callback = lambda do |call, _value|
        next unless call == :first

        release << true
        raise 'callback failed'
      end

      expect do
        Timeout.timeout(2) do
          described_class.run(mode, tool_calls, on_result: callback) do |call|
            if call == :first
              ready.pop
            else
              ready << true
              release.pop
              finished << call
            end
            call
          end
        end
      end.to raise_error(RuntimeError, 'callback failed')
      expect(finished.pop).to eq(:second)
    ensure
      release << true
    end

    it "returns an empty result without callbacks using #{mode}" do
      reported = []

      result = described_class.run(mode, {}, on_result: ->(*) { reported << true }) { raise 'no tools' }

      expect(result).to eq([])
      expect(reported).to be_empty
    end

    it "finishes every #{mode} worker before propagating tool errors" do
      finished = Queue.new
      failure = ArgumentError.new('tool failed')

      expect do
        described_class.run(mode, tool_calls) do |call|
          finished << call
          raise failure
        end
      end.to(raise_error { |error| expect(error).to equal(failure) })
      expect(Array.new(2) { finished.pop }).to contain_exactly(:first, :second)
    end

    %i[run complete].each do |phase|
      it "propagates Rails executor #{phase} failures from #{mode} workers" do
        failure = RuntimeError.new("executor #{phase} failed")
        calls = executor_calls
        execution = Object.new
        execution.define_singleton_method(:complete!) do
          calls << :complete
          raise failure if phase == :complete
        end
        allow(executor).to receive(:run!) do
          executor_calls << :run
          raise failure if phase == :run

          execution
        end
        stub_rails_executor(executor)

        with_isolation(:fiber) do
          in_reactor do
            expect { described_class.run(mode, tool_calls) { :ok } }
              .to(raise_error { |error| expect(error).to equal(failure) })
          end
        end
        expect(executor_events).to eq(phase == :run ? { run: 2 } : { run: 2, complete: 2 })
      end
    end
  end

  it 'propagates fiber context setup failures inside an existing reactor' do
    failure = RuntimeError.new('context setup failed')
    with_failing_context(failure) do
      in_reactor do
        error = error_without_watchdog { described_class.run(:fibers, tool_calls) { :ok } }
        expect(error).to equal(failure)
      end
    end
  end

  it 'joins already started threads when a later thread cannot start' do
    release = Queue.new
    worker = nil
    launches = 0
    failure = ThreadError.new('thread could not start')
    allow(Thread).to receive(:new).and_wrap_original do |original, &block|
      launches += 1
      raise failure if launches == 2

      worker = original.call(&block)
      allow(worker).to receive(:join).and_wrap_original do |join|
        release << true
        join.call
      end
      worker
    end

    expect { described_class.run(:threads, tool_calls) { release.pop } }
      .to(raise_error { |error| expect(error).to equal(failure) })
    expect(worker).not_to be_alive
  ensure
    release << true
    worker&.join
  end

  it 'waits for already started fibers when a later task cannot start' do
    child = nil
    in_reactor do |task|
      task.with_timeout(2) do
        require 'async/queue'
        release = Async::Queue.new
        launches = 0
        failure = RuntimeError.new('task could not start')
        allow(task).to receive(:async).and_wrap_original do |original, &block|
          launches += 1
          raise failure if launches == 2

          child = original.call(&block)
          allow(child).to receive(:wait).and_wrap_original do |wait|
            release << true
            wait.call
          end
          child
        end

        expect { described_class.run(:fibers, tool_calls) { release.pop } }
          .to(raise_error { |error| expect(error).to equal(failure) })
        expect(child).not_to be_alive
      ensure
        child&.stop
      end
    end
  end

  it 'does not turn an Async stop into a successful tool result' do
    reported = []
    in_reactor do |task|
      task.with_timeout(2) do
        child = task.async do
          described_class.run(:fibers, tool_calls, on_result: ->(*) { reported << true }) { raise Async::Stop }
          reported << :returned
        end
        child.wait

        expect(child).to be_stopped
        expect(child).not_to be_alive
      ensure
        child&.stop
      end
    end
    expect(reported).to be_empty
  end

  it 'propagates interrupts from tool threads without successful callbacks' do
    reported = []

    error = error_without_watchdog do
      described_class.run(:threads, tool_calls, on_result: ->(*) { reported << true }) { raise Interrupt }
    rescue Interrupt => e
      e
    end
    expect(error).to be_a(Interrupt)
    expect(reported).to be_empty
  end
end
