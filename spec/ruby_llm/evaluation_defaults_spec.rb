# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:openai) }
  let(:cases) { [described_class::Case.new(name: 'greeting', inputs: 'Hello', expected_output: 'HELLO')] }
  let(:requests) { [] }
  let(:evaluation) do
    Class.new(described_class) do
      def perform(input)
        input
      end
    end
  end

  before do
    RubyLLM.config.default_model = model
    stub_request(:post, 'https://api.openai.com/v1/responses').to_return do |request|
      body = JSON.parse(request.body)
      requests << body
      verdicts = body.dig('text', 'format', 'schema', 'required').to_h do |name|
        [name, { verdict: 'pass', reason: 'The answer satisfies the criterion.' }]
      end
      { status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
        id: 'resp_evaluation', model:, status: 'completed',
        output: [{ type: 'message', role: 'assistant',
                   content: [{ type: 'output_text', text: JSON.generate(verdicts), annotations: [] }] }],
        usage: { input_tokens: 100, output_tokens: 20 }
      }.to_json }
    end
  end

  def criteria
    requests.map { |request| request.dig('text', 'format', 'schema', 'required') }
  end

  it 'grades a perform-only evaluation against the reference using the configured default model' do
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed, report.to_s
    expect(report.first.assertion_count).to eq(0)
    expect(criteria).to eq([['correctness']])
    expect(report.definitions).to contain_exactly(
      include(name: 'correctness', instructions: 'The answer agrees with the expected output')
    )
    evidence = JSON.parse(requests.first['input'].last['content'])
    expect(evidence).to include('inputs' => 'Hello', 'actual' => 'Hello', 'expected_output' => 'HELLO')
    expect(report.tokens.input).to eq(100)
    expect(report.cost.total).to eq(report.first.evaluator_cost.total)
  end

  it 'keeps default correctness when Ruby assertions are added' do
    evaluation.define_method(:assertions) { assert_equal 'Goodbye', output }
    report = evaluation.run(dataset: cases)

    expect(report.first.status).to eq(:failed)
    expect(report.first.assertion_failure).to be_a(Minitest::Assertion)
    expect(report.first.evaluations.first).to be_passed
    expect(criteria).to eq([['correctness']])
  end

  it 'uses explicitly declared criteria as the complete set without requiring references' do
    evaluation.evaluation(:grounded, 'Every claim has a citation')
    report = evaluation.run(dataset: [described_class::Case.new(name: 'citation', inputs: 'See [1]')])

    expect(report).to be_passed
    expect(criteria).to eq([['grounded']])
    expect(report.definitions).to contain_exactly(include(name: 'grounded', instructions: 'Every claim has a citation'))
  end

  it 'allows custom correctness instructions without adding the built-in definition' do
    evaluation.evaluation(:correctness, 'The response contains the order number')
    report = evaluation.run(dataset: [described_class::Case.new(name: 'order', inputs: 'Order 42')])

    expect(report).to be_passed
    expect(criteria).to eq([['correctness']])
    expect(report.definitions).to contain_exactly(include(instructions: 'The response contains the order number'))
  end

  it 'includes built-in correctness explicitly alongside another criterion in one request' do
    evaluation.evaluation(:correctness)
    evaluation.evaluation(:concise, 'The answer contains no unnecessary detail')
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed
    expect(criteria).to eq([%w[correctness concise]])
    expect(report.first.evaluations.map(&:name)).to eq(%i[correctness concise])
    expect(report.tokens.input).to eq(100)
  end

  it 'validates all selected references before starting any case' do
    cases << described_class::Case.new(name: 'missing', inputs: 'No reference')
    allow(evaluation).to receive(:new).and_call_original

    expect { evaluation.run(dataset: cases) }.to raise_error(ArgumentError, /expected_output.*missing/)
    expect(evaluation).not_to have_received(:new)
    expect(requests).to be_empty
    expect(evaluation.run(dataset: cases, only: 'greeting')).to be_passed
  end

  it 'requires references for explicitly requested built-in correctness too' do
    evaluation.evaluation(:correctness)
    dataset = [described_class::Case.new(name: 'missing', inputs: 'Hello')]

    expect { evaluation.run(dataset:) }.to raise_error(ArgumentError, /expected_output.*missing/)
    expect(requests).to be_empty
  end

  it 'accepts false, zero, and explicit null as reference values' do
    dataset = [false, 0, nil].map do |value|
      described_class::Case.new(name: value.inspect, inputs: value, expected_output: value)
    end
    report = evaluation.run(dataset:)

    expect(report).to be_passed
    expect(requests.map { |request| JSON.parse(request['input'].last['content']).fetch('expected_output') })
      .to eq([false, 0, nil])
  end

  it 'disables model grading explicitly while keeping Ruby assertions and reports' do
    evaluation.evaluator(false)
    evaluation.define_method(:assertions) { refute_empty output }
    report = evaluation.run(dataset: [described_class::Case.new(name: 'no_reference', inputs: 'Hello')])

    expect(evaluation.evaluator).to be(false)
    expect(report).to be_passed
    expect(report.definitions).to be_empty
    expect(report.first.evaluations).to be_empty
    expect(report.first.assertion_count).to be_positive
    expect(report.cost.total).to be_nil
    expect(requests).to be_empty
  end

  it 'does not pass an evaluation with grading disabled and no assertions' do
    evaluation.evaluator(false)

    expect(evaluation.run(dataset: cases).first.status).to eq(:measured)
    expect(requests).to be_empty
  end

  it 'inherits disabled grading and lets a child reenable it without changing its parent' do
    evaluation.evaluator(false)
    disabled = Class.new(evaluation)
    enabled = Class.new(disabled)
    enabled.evaluator(model:, provider: :openai)

    expect(disabled.evaluator).to be(false)
    expect(enabled.run(dataset: cases)).to be_passed
    expect(evaluation.evaluator).to be(false)
  end

  it 'does not turn resolved defaults into inherited explicit criteria' do
    evaluation.run(dataset: cases)
    child = Class.new(evaluation)
    child.evaluation(:concise, 'The answer is brief')
    child.run(dataset: cases)
    evaluation.run(dataset: cases)

    expect(criteria).to eq([['correctness'], ['concise'], ['correctness']])
    expect(evaluation.definitions).to be_empty
  end

  it 'allows inherited correctness instructions to be replaced without modifying the parent' do
    evaluation.evaluation(:correctness, 'The answer preserves every reference fact')
    child = Class.new(evaluation)
    child.evaluation(:correctness)

    expect(child.run(dataset: cases).definitions.first[:instructions])
      .to eq('The answer agrees with the expected output')
    expect(evaluation.run(dataset: cases).definitions.first[:instructions])
      .to eq('The answer preserves every reference fact')
  end

  it 'rejects contradictory disabled grading configurations' do
    expect { evaluation.evaluator(false, model:) }.to raise_error(ArgumentError, /disabled evaluator/)
    evaluation.evaluator(false)
    evaluation.evaluation(:correctness)

    expect { evaluation.run(dataset: cases) }.to raise_error(ArgumentError, /semantic evaluations with evaluator false/)
    expect(requests).to be_empty
  end

  context 'with a decision model' do
    before do
      stub_request(:post, 'https://api.typesafe.ai/v1/systemone').to_return do |request|
        body = JSON.parse(request.body)
        requests << body
        answers = body.fetch('questions').keys.to_h { |name| [name, { type: 'noul', noul: 0.9 }] }
        { status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
          model: model_for(:typesafe, :judgment), answers:, usage: { input_tokens: 80, output_tokens: 1 }
        }.to_json }
      end
    end

    it 'uses a configured Judge own questions including correctness without imposing reference requirements' do
      judge = Class.new(RubyLLM::Judge) do
        probability :correctness, 'The answer follows the policy in its citations'
        probability :grounded, 'The answer cites its sources'
      end
      judge.model(model_for(:typesafe, :judgment), provider: :typesafe)
      evaluation.evaluator(judge)
      evaluation.evaluation(:correctness, minimum: 0.8)
      report = evaluation.run(dataset: [described_class::Case.new(name: 'policy', inputs: 'See [1]')])

      expect(report.first.evaluations.map(&:name)).to eq(%i[correctness grounded])
      expect(report.first.evaluations.first).to be_passed
      expect(requests.first.dig('questions', 'correctness', 'instructions'))
        .to eq('The answer follows the policy in its citations')
    end

    it 'retains native correctness probabilities and requires an explicit threshold to count them as passes' do
      evaluation.evaluator(model: model_for(:typesafe, :judgment), provider: :typesafe)
      measured = evaluation.run(dataset: cases)
      evaluation.evaluation(:correctness, minimum: 0.8)
      accepted = evaluation.run(dataset: cases)

      expect(measured.first.status).to eq(:measured)
      expect(measured.first.evaluations.first.value).to be_a(RubyLLM::Probability)
      expect(accepted).to be_passed
      expect(requests.last.dig('questions', 'correctness', 'instructions'))
        .to eq('The answer agrees with the expected output')
    end
  end
end
