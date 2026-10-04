# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  let(:instrumenter) { CaptureInstrumenter.new }
  let(:cases) do
    [described_class::Case.new(name: 'greeting', inputs: 'hello', expected_output: 'HELLO'),
     described_class::Case.new(name: 'mismatch', inputs: 'bye', expected_output: 'HELLO'),
     described_class::Case.new(name: 'broken', inputs: nil)]
  end
  let(:evaluation) do
    Class.new(described_class) do
      def perform(input)
        input.upcase
      end

      def assertions
        assert_equal expected_output, output
      end
    end
  end

  before do
    RubyLLM.config.instrumenter = instrumenter
    stub_const('GreetingEvaluation', evaluation)
  end

  it 'yields completed trials after cleanup and before starting the next case' do
    timeline = []
    evaluation.define_method(:setup) { timeline << [:setup, input] }
    evaluation.define_method(:teardown) { timeline << [:teardown, input] }
    delivered = []

    report = evaluation.run(dataset: cases, repetitions: 2) do |trial|
      timeline << [:delivered, trial.test_case.inputs]
      delivered << trial
      expect(trial).to be_frozen
      expect { JSON.generate(trial.to_h) }.not_to raise_error
      :ignored
    end

    expect(report.trials).to eq(delivered)
    expect(delivered.map(&:status)).to eq(%i[passed passed failed failed error error])
    expect(timeline).to eq(cases.flat_map do |test_case|
      [[:setup, test_case.inputs], [:teardown, test_case.inputs], [:delivered, test_case.inputs]] * 2
    end)
  end

  it 'publishes progress and the final report through the existing instrumenter' do
    report = evaluation.run(dataset: cases, only: %w[mismatch broken], repetitions: 2, id: 'run-42')
    events = instrumenter.events.select { |name, _| name.start_with?('evaluation') }
    trials = events[0...-1].map(&:last)

    expect(events.map(&:first)).to eq((['evaluation_trial.ruby_llm'] * 4) + ['evaluation.ruby_llm'])
    expect(trials.map { |payload| payload[:completed] }).to eq([1, 2, 3, 4])
    expect(trials.map { |payload| payload[:repetition] }).to eq([1, 2, 1, 2])
    expect(trials.map { |payload| payload[:case] }).to eq(%w[mismatch mismatch broken broken])
    expect(trials.map { |payload| payload[:trial] }).to eq(report.trials)
    expect(trials).to all(include(evaluation_id: 'run-42', evaluation_name: 'GreetingEvaluation', total: 4))
    expect(events.last.last).to include(report:, completed: 4, total: 4, started_at: report.started_at)
    expect(report.id).to eq('run-42')
    workflows = instrumenter.events.filter_map { |name, payload| payload if name == 'workflow.ruby_llm' }
    expect(workflows).to all(include(workflow_id: report.id))
  end

  it 'reports an interrupted run without reclassifying the completed trial as an error' do
    RubyLLM.config.instrumenter = ActiveSupport::Notifications
    events = []
    subscriber = ActiveSupport::Notifications.subscribe(/\Aevaluation(?:_trial)?\.ruby_llm\z/) do |event|
      events << event
    end
    cleanups = []
    evaluation.define_method(:teardown) { cleanups << input }

    expect do
      evaluation.run(dataset: cases) { raise 'UI storage failed' }
    end.to raise_error('UI storage failed')

    expect(cleanups).to eq(['hello'])
    expect(events.map(&:name)).to eq(%w[evaluation_trial.ruby_llm evaluation.ruby_llm])
    expect(events.first.payload.fetch(:trial)).to be_passed
    expect(events.last.payload).to include(completed: 1, total: 3, exception: ['RuntimeError', 'UI storage failed'])
    expect(events.last.payload).not_to have_key(:report)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it 'keeps nested run identities and progress independent' do
    inner = nil
    outer = evaluation.run(dataset: cases, only: 'greeting', id: 'outer') do
      inner = evaluation.run(dataset: cases, only: 'greeting', repetitions: 2, id: 'inner')
    end
    payloads = instrumenter.events.filter_map { |name, payload| payload if name == 'evaluation.ruby_llm' }

    expect(payloads).to contain_exactly(
      include(evaluation_id: 'inner', completed: 2, total: 2, report: inner),
      include(evaluation_id: 'outer', completed: 1, total: 1, report: outer)
    )
  end

  it 'generates distinct run identities and normalizes supplied application IDs' do
    first = evaluation.run(dataset: cases, only: 'greeting')
    second = evaluation.run(dataset: cases, only: 'greeting')

    expect(first.id).not_to eq(second.id)
    expect(evaluation.run(dataset: cases, only: 'greeting', id: 42).id).to eq('42')
  end

  it 'rejects invalid configuration before publishing progress or yielding trials' do
    allow(evaluation).to receive(:new).and_call_original
    expect do
      evaluation.run(dataset: cases, id: '') { raise 'unexpected progress' }
    end.to raise_error(ArgumentError, /id cannot be empty/)
    expect do
      evaluation.run(dataset: cases, only: 'missing') { raise 'unexpected progress' }
    end.to raise_error(ArgumentError, /Unknown evaluation cases/)
    expect(instrumenter.events).to be_empty
    expect(evaluation).not_to have_received(:new)
  end
end
