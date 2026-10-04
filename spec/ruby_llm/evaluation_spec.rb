# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  let(:cases) do
    [RubyLLM::Evaluation::Case.new(name: 'greeting', inputs: 'hello', expected_output: 'HELLO')]
  end
  let(:evaluation) do
    Class.new(described_class) do
      def perform(input)
        input.upcase
      end

      def assertions
        assert_equal expected_output, output
        refute_empty output
      end
    end
  end

  it 'runs ordinary assertions without calling a model' do
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed
    expect(report.first.output).to eq('HELLO')
    expect(report.first.result).to eq('HELLO')
    expect(report.first.assertion_count).to be >= 3
    expect(report.pass_rate).to eq(1.0)
    expect(report.to_s).to include('greeting [1]: passed')
  end

  it 'records failed assertions and continues to later cases' do
    cases << RubyLLM::Evaluation::Case.new(name: 'bad', inputs: 'wrong', expected_output: 'RIGHT')
    report = evaluation.run(dataset: cases)

    expect(report.map(&:status)).to eq(%i[passed failed])
    expect(report.trials.last.assertion_failure).to be_a(Minitest::Assertion)
    expect(report.pass_rate).to eq(0.5)
    expect(report).not_to be_passed
    expect(report.to_s).to include('RIGHT', 'WRONG')
  end

  it 'lists and selects named cases without executing the application during discovery' do
    cases << RubyLLM::Evaluation::Case.new(name: 'second', inputs: 'bye', expected_output: 'BYE')
    expect(evaluation.cases(dataset: cases, only: 'second')).to eq([cases.last])
    report = evaluation.run(dataset: cases, only: 'second')

    expect(report.map { |trial| trial.test_case.name }).to eq(['second'])
    expect(report).to be_passed
    expect { evaluation.run(dataset: cases, only: 'typo') }.to raise_error(ArgumentError, /Unknown evaluation cases/)
    expect { evaluation.run(dataset: cases, only: []) }.to raise_error(ArgumentError, /Unknown evaluation cases/)
  end

  it 'isolates input mutations and instance state across cases and repetitions' do
    evaluation = Class.new(described_class) do
      def perform(input)
        @counter = @counter.to_i + 1
        input << @counter
      end

      def assertions
        assert_equal [1], output
      end
    end
    original = RubyLLM::Evaluation::Case.new(name: 'mutable', inputs: [])
    report = evaluation.run(dataset: [original], repetitions: 3)

    expect(report.map(&:output)).to eq([[1], [1], [1]])
    expect(report.map(&:repetition)).to eq([1, 2, 3])
    expect(original.inputs).to eq([])
  end

  it 'records task errors and runs teardown' do
    cleanups = []
    evaluation.define_method(:perform) { |_input| raise 'task failed' }
    evaluation.define_method(:teardown) { cleanups << true }
    report = evaluation.run(dataset: cases, repetitions: 2)

    expect(report.map(&:status)).to eq(%i[error error])
    expect(report.first.error.message).to eq('task failed')
    expect(cleanups).to eq([true, true])
    expect(report.pass_rate).to eq(0.0)
  end

  it 'records cleanup errors without discarding the trial' do
    evaluation.define_method(:teardown) { raise 'cleanup failed' }
    report = evaluation.run(dataset: cases)

    expect(report.first.status).to eq(:error)
    expect(report.first.error.message).to eq('cleanup failed')
  end

  it 'does not pass a case that assessed nothing' do
    evaluation.define_method(:assertions) { nil }

    expect(evaluation.run(dataset: cases).first.status).to eq(:measured)
  end

  it 'inherits criteria and adapters without modifying the parent' do
    evaluation.evaluation(:correct, 'Correct answer')
    child = Class.new(evaluation)
    child.evaluation(:correct, 'A more specific criterion')
    child.evaluation(:short, 'Short answer')
    child.adapt(Struct, &:to_h)

    expect(evaluation.definitions.keys).to eq([:correct])
    expect(evaluation.definitions[:correct][:instructions]).to eq('Correct answer')
    expect(evaluation.adapters).to be_empty
    expect { child.evaluation(:short, 'Duplicate') }.to raise_error(ArgumentError, /Duplicate/)
  end

  it 'rejects invalid runs and incomplete definitions before executing' do
    expect { evaluation.run(dataset: [], repetitions: 0) }.to raise_error(ArgumentError, /Repetitions/)
    expect { evaluation.run(dataset: []) }.to raise_error(ArgumentError, /empty/)
    expect { evaluation.run(dataset: cases * 2) }.to raise_error(ArgumentError, /unique/)
    evaluation.evaluation(:correct)
    expect { evaluation.run(dataset: cases) }.to raise_error(ArgumentError, /Missing instructions/)
  end

  it 'discovers YAML by class name under app/evals and rejects ambiguous matches' do
    Dir.mktmpdir do |directory|
      allow(RubyLLM::Prompt).to receive(:root).and_return(Pathname.new(directory).join('app/prompts'))
      root = File.join(directory, 'app/evals')
      FileUtils.mkdir_p(root)
      stub_const('GreetingEvaluation', evaluation)
      File.write(File.join(root, 'greeting_evaluation.yml'), YAML.dump('cases' => cases.map(&:to_h).as_json))

      expect(evaluation.run).to be_passed
      File.write(File.join(root, 'greeting_evaluation.json'), JSON.generate(cases.map(&:to_h)))
      expect { evaluation.run }.to raise_error(ArgumentError, /Ambiguous/)
    end
  end

  it 'loads YAML, JSON, and JSONL with the same data and explicit paths' do
    Dir.mktmpdir do |directory|
      files = { 'yml' => YAML.dump('cases' => cases.map(&:to_h).as_json),
                'json' => JSON.generate(cases.map(&:to_h)), 'jsonl' => JSON.generate(cases.first.to_h) }
      files.each do |extension, body|
        path = File.join(directory, "cases.#{extension}")
        File.write(path, body)
        evaluation.dataset(path)
        expect(evaluation.run).to be_passed
      end
    end
  end

  it 'loads enumerable cases from a dataset block once per run' do
    runs = 0
    rows = cases
    evaluation.dataset do
      runs += 1
      rows.each
    end

    expect(evaluation.run(repetitions: 2)).to be_passed
    expect(runs).to eq(1)
  end

  it 'rejects unsafe YAML instead of constructing arbitrary objects' do
    Tempfile.create(['evaluation', '.yml']) do |file|
      file.write("--- !ruby/object:Object {}\n")
      file.flush
      expect { evaluation.run(dataset: file.path) }.to raise_error(Psych::DisallowedClass)
    end
  end

  it 'preserves false, zero, and explicit nil reference answers' do
    [false, 0, nil].each do |expected|
      test_case = RubyLLM::Evaluation::Case.new(name: 'value', inputs: expected, expected_output: expected)
      evaluation.define_method(:perform) { |input| input }
      evaluation.define_method(:assertions) do
        expected_output.nil? ? assert_nil(output) : assert_equal(expected_output, output)
      end
      expect(evaluation.run(dataset: [test_case])).to be_passed
      expect(test_case).to be_expected_output
      expect(test_case.to_h).to have_key(:expected_output)
    end
    expect(RubyLLM::Evaluation::Case.new(name: 'no_reference', inputs: nil)).not_to be_expected_output
  end

  it 'saves reports with failed cases and serializable evidence' do
    report = evaluation.run(dataset: cases)
    Tempfile.create(['report', '.json']) do |file|
      expect(report.save(file.path)).to eq(file.path)
      data = JSON.parse(File.read(file.path))
      expect(data.fetch('trials').first).to include('status' => 'passed', 'evidence' => 'HELLO')
      expect(data.fetch('id')).to eq(report.id)
    end
  end

  it 'rejects imported executable evaluators instead of silently ignoring their checks' do
    expect do
      evaluation.run(dataset: { cases:, evaluators: ['EqualsExpected'] })
    end.to raise_error(ArgumentError, /declare evaluators in Ruby/)
  end

  it 'runs teardown when setup fails and keeps the original error' do
    cleanups = []
    evaluation.define_method(:setup) { raise 'setup failed' }
    evaluation.define_method(:teardown) do
      cleanups << true
      raise 'cleanup also failed'
    end
    report = evaluation.run(dataset: cases)

    expect(report.first.error.message).to eq('setup failed')
    expect(cleanups).to eq([true])
  end

  it 'rejects an evaluation without perform before starting cases' do
    expect { Class.new(described_class).run(dataset: cases) }.to raise_error(ArgumentError, /Define perform/)
  end

  it 'rejects conflicting dataset arguments and invalid acceptance thresholds' do
    expect { evaluation.dataset(cases) { cases } }.to raise_error(ArgumentError, /not both/)
    expect { evaluation.evaluation(:correct, 'Correct', minimum: Float::NAN) }.to raise_error(ArgumentError, /finite/)
    expect { evaluation.evaluation('', 'Correct') }.to raise_error(ArgumentError, /empty/)
    expect { evaluation.evaluator(Object.new) }.to raise_error(ArgumentError, /evaluator/)
  end
end
