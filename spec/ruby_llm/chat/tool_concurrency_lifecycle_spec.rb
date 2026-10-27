# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat::ToolConcurrency do
  %i[threads fibers].each do |mode|
    it "finishes repeated #{mode} workers without leaking caller context" do
      workers = Queue.new
      observed = Queue.new
      listener = ->(_progress) {}
      calls = (1..10).to_h { |id| [id, id] }

      RubyLLM.with_usage_owner('caller') do
        RubyLLM::Support::ProgressReporter.listen(listener) do
          3.times do
            results = Timeout.timeout(5) do
              described_class.run(mode, calls) do |call|
                workers << (mode == :threads ? Thread.current : Async::Task.current)
                RubyLLM.with_usage_owner('worker') do
                  RubyLLM::Support::ProgressReporter.listen(nil) { :work }
                end
                observed << [RubyLLM::Accounting::Usage.owner, RubyLLM::Support::ProgressReporter.listener]
                call
              end
            end
            expect(results).to eq(calls.map { |_, call| [call, call] })
          end
          expect(RubyLLM::Accounting::Usage.owner).to eq('caller')
          expect(RubyLLM::Support::ProgressReporter.listener).to equal(listener)
        end
      end

      expect(Array.new(30) { workers.pop }).not_to include(satisfy(&:alive?))
      expect(Array.new(30) { observed.pop }).to all(eq(['caller', listener]))
      expect(RubyLLM::Accounting::Usage.owner).to be_nil
      expect(RubyLLM::Support::ProgressReporter.listener).to be_nil
    end
  end
end
