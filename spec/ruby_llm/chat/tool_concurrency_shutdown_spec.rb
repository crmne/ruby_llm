# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat::ToolConcurrency do
  it 'closes worker resources when the host stops the parent async task' do
    workers = []
    closed = []
    reported = []
    runner = nil

    in_reactor do |task|
      require 'async/queue'
      ready = Async::Queue.new
      collecting = Async::Queue.new
      unrelated = task.async { sleep }
      allow(described_class).to receive(:collect_results).and_wrap_original do |original, *arguments, **options|
        collecting << true
        original.call(*arguments, **options)
      end
      release = Async::Queue.new
      task.with_timeout(2) do
        runner = task.async do
          described_class.run(:fibers, { first: :first, second: :second },
                              on_result: ->(*) { reported << :result }) do |call|
            workers << Async::Task.current
            ready << true
            begin
              release.pop
            ensure
              closed << call
            end
          end
          reported << :returned
        end
        collecting.pop
        2.times { ready.pop }
        runner.stop
        runner.wait
        task.yield

        expect(runner).not_to be_alive
        expect(workers).not_to include(satisfy(&:alive?))
        expect(closed).to contain_exactly(:first, :second)
        expect(reported).to be_empty
        expect(unrelated).to be_alive
      ensure
        2.times { release << true }
        runner&.stop
        workers.each(&:stop)
        unrelated.stop
      end
    end
  end

  it 'stops waiting workers when a result callback stops the async task' do
    in_reactor do |task|
      require 'async/queue'
      release = Async::Queue.new
      closed = []
      reported = []
      workers = []
      task.with_timeout(2) do
        runner = task.async do
          described_class.run(:fibers, { first: :first, second: :second }, on_result: lambda { |call, _|
            reported << call
            raise Async::Stop
          }) do |call|
            workers << Async::Task.current
            begin
              release.pop if call == :second
              call
            ensure
              closed << call
            end
          end
          reported << :returned
        end
        runner.wait
        task.yield

        expect(runner).to be_stopped
        expect(workers).not_to include(satisfy(&:alive?))
        expect(closed).to contain_exactly(:first, :second)
        expect(reported).to eq([:first])
      ensure
        release << true
        workers.each(&:stop)
        runner&.stop
      end
    end
  end

  it 'preserves cancellation before any worker is started' do
    in_reactor do |task|
      require 'async/queue'
      allow(Async::Queue).to receive(:new).and_raise(Async::Stop)
      task.with_timeout(2) do
        runner = task.async { described_class.run(:fibers, { first: :first }) { :work } }
        runner.wait

        expect(runner).to be_stopped
      ensure
        runner&.stop
      end
    end
  end
end
