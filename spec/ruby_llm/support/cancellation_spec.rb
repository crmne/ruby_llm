# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Support::Cancellation do
  it 'passes checkpoints to child fibers' do
    checks = []

    described_class.watch(-> { checks << :checked }) do
      Fiber.new { described_class.check }.resume
    end

    expect(checks).to eq([:checked])
  end

  it 'passes checkpoints to async child tasks' do
    checks = []

    in_reactor do |task|
      described_class.watch(-> { checks << :checked }) do
        task.async { described_class.check }.wait
      end
    end

    expect(checks).to eq([:checked])
  end

  it 'checks the current cancellation signal after a child has started' do
    cancelled = false
    child = nil

    in_reactor do |task|
      task.with_timeout(2) do
        require 'async/queue'
        release = Async::Queue.new
        described_class.watch(-> { raise RubyLLM::CancelledError if cancelled }) do
          child = task.async do
            release.pop
            described_class.check
          end
          cancelled = true
          release << true

          expect { child.wait }.to raise_error(RubyLLM::CancelledError)
        end
      end
    end

    expect(child).not_to be_alive
  end

  it 'restores nested checkpoints after errors and clears the outer scope' do
    checks = []

    described_class.watch(-> { checks << :outer }) do
      expect do
        described_class.watch(-> { checks << :inner }) do
          described_class.check
          raise 'failure'
        end
      end.to raise_error(RuntimeError, 'failure')
      described_class.check
    end
    described_class.check

    expect(checks).to eq(%i[inner outer])
  end

  it 'isolates checkpoint overrides in sibling fibers' do
    checks = []

    described_class.watch(-> { checks << :parent }) do
      first = Fiber.new do
        described_class.watch(-> { checks << :first }) do
          Fiber.yield
          described_class.check
        end
        described_class.check
      end
      second = Fiber.new { described_class.check }
      first.resume
      second.resume
      first.resume
      described_class.check
    end

    expect(checks).to eq(%i[parent first parent parent])
  end

  it 'respects children that explicitly disable storage inheritance' do
    checks = []

    described_class.watch(-> { checks << :parent }) do
      Fiber.new(storage: nil) { described_class.check }.resume
    end

    expect(checks).to be_empty
  end

  it 'keeps the checkpoint inherited when a fiber was created' do
    checks = []
    child = described_class.watch(-> { checks << :parent }) { Fiber.new { described_class.check } }

    child.resume
    described_class.check

    expect(checks).to eq([:parent])
  end
end
