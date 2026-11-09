# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'
require 'ruby_llm/active_record/solid_queue_shutdown'

RSpec.describe RubyLLM::ActiveRecord::SolidQueueShutdown do
  include ActiveSupport::Testing::TimeHelpers

  let(:hooks) { {} }
  let(:solid_queue) do
    registered = hooks
    Module.new do
      define_singleton_method(:shutdown_timeout) { 5.seconds }
      define_singleton_method(:on_worker_stop) { |&block| registered[:worker] = block }
      define_singleton_method(:on_stop) { |&block| registered[:supervisor] = block }
    end
  end

  before do
    allow(RubyLLM::ActiveRecord::RunClaims).to receive(:process_exits_by)
    described_class.install(solid_queue)
  end

  def supervisor(pid: Process.pid, mode: nil)
    Struct.new(:pid, :mode).new(pid, mode&.inquiry)
  end

  def worker(supervisor)
    Struct.new(:supervisor).new(supervisor)
  end

  it 'ends the claims of a forked worker by its shutdown timeout, when it exits' do
    freeze_time do
      hooks[:worker].call(worker(supervisor(pid: Process.pid + 1)))

      expect(RubyLLM::ActiveRecord::RunClaims).to have_received(:process_exits_by).with(5.seconds.from_now)
    end
  end

  it 'leaves a worker that runs as a thread of its supervisor alone, since replacing it keeps the process' do
    hooks[:worker].call(worker(supervisor))

    expect(RubyLLM::ActiveRecord::RunClaims).not_to have_received(:process_exits_by)
  end

  it 'leaves a worker without a supervisor alone' do
    hooks[:worker].call(worker(nil))

    expect(RubyLLM::ActiveRecord::RunClaims).not_to have_received(:process_exits_by)
  end

  it 'ends the claims of the threads of an async supervisor by its shutdown timeout' do
    freeze_time do
      hooks[:supervisor].call(supervisor(mode: 'async'))

      expect(RubyLLM::ActiveRecord::RunClaims).to have_received(:process_exits_by).with(5.seconds.from_now)
    end
  end

  it 'leaves the claims alone when a supervisor of forks stops, since its workers end their own' do
    hooks[:supervisor].call(supervisor(mode: 'fork'))
    hooks[:supervisor].call(Object.new)

    expect(RubyLLM::ActiveRecord::RunClaims).not_to have_received(:process_exits_by)
  end

  it 'installs itself when Solid Queue loads' do
    hooks.clear
    ActiveSupport.run_load_hooks(:solid_queue, solid_queue)

    expect(hooks.keys).to contain_exactly(:worker, :supervisor)
  end
end
