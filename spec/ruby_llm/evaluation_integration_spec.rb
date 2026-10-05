# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe RubyLLM::Evaluation do
  let(:library) { File.expand_path('../../lib', __dir__) }
  let(:directory) { Dir.mktmpdir }
  let(:source) do
    <<~RUBY
      require 'ruby_llm'
      class FormattingEvaluation < RubyLLM::Evaluation
        evaluator false

        def perform(input)
          input.upcase
        end

        def assertions
          assert_equal expected_output, output
        end
      end
    RUBY
  end

  around do |example|
    FileUtils.mkdir_p(File.join(directory, 'app/evals'))
    File.write(File.join(directory, 'app/evals/formatting_evaluation.rb'), source)
    File.write(File.join(directory, 'app/evals/formatting_evaluation.yml'), <<~YAML)
      cases:
        - name: correct
          inputs: hello
          expected_output: HELLO
        - name: regression
          inputs: goodbye
          expected_output: BONJOUR
    YAML
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def run_script(source)
    Open3.capture3(RbConfig.ruby, '-I', library, '-e', source, chdir: directory)
  end

  it 'runs separate RSpec examples and includes the actual failed assertion in its report' do
    output, error, status = run_script(<<~RUBY)
      require 'rspec/autorun'
      require_relative 'app/evals/formatting_evaluation'
      RSpec.describe FormattingEvaluation do
        extend RubyLLM::Evaluation::RSpec
        evaluates described_class
      end
    RUBY

    expect(status.exitstatus).to eq(1), error
    expect(output).to include('2 examples, 1 failure', 'regression', 'BONJOUR', 'GOODBYE')
  end

  it 'runs separate Minitest tests with ordinary assertion failures' do
    output, error, status = run_script(<<~RUBY)
      require 'minitest/autorun'
      require_relative 'app/evals/formatting_evaluation'
      class FormattingTest < Minitest::Test
        extend RubyLLM::Evaluation::Minitest
        evaluates FormattingEvaluation
      end
    RUBY

    expect(status.exitstatus).to eq(1), error
    expect(output).to include('2 runs', '1 failures', '0 errors', 'regression', 'BONJOUR', 'GOODBYE')
  end

  it 'discovers conventional evaluations from rake, saves reports, and fails on regressions' do
    output, error, status = run_script(<<~RUBY)
      require 'rake'
      load 'tasks/ruby_llm.rake'
      Rake::Task['ruby_llm:eval'].invoke
    RUBY

    expect(status.exitstatus).to eq(1)
    expect(error).to include('Evaluations failed')
    expect(output).to include('correct [1]: passed', 'regression [1]: failed', 'BONJOUR')
    report = JSON.parse(File.read(File.join(directory, 'tmp/evaluations/FormattingEvaluation.json')))
    expect(report.fetch('counts')).to include('passed' => 1, 'failed' => 1)
  end

  it 'loads the application environment and selects an evaluation and case from rake' do
    output, error, status = run_script(<<~RUBY)
      require 'rake'
      task(:environment) { puts 'Environment loaded' }
      load 'tasks/ruby_llm.rake'
      Rake::Task['ruby_llm:eval'].invoke('FormattingEvaluation', 'correct')
    RUBY

    expect(status).to be_success, error
    expect(output).to include('Environment loaded', '1 passed, 0 failed')
    expect(output).not_to include('regression')
  end

  it 'rejects a misspelled evaluation instead of passing an empty run' do
    _output, error, status = run_script(<<~RUBY)
      require 'rake'
      load 'tasks/ruby_llm.rake'
      Rake::Task['ruby_llm:eval'].invoke('MissingEvaluation')
    RUBY

    expect(status).not_to be_success
    expect(error).to include('No evaluations found', 'MissingEvaluation')
  end
end
