# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation::Evaluator do
  include_context 'with configured RubyLLM'

  let(:cases) { [RubyLLM::Evaluation::Case.new(name: 'answer', inputs: 'hello', expected_output: 'HELLO')] }
  let(:model) { model_for(:openai) }
  let(:requests) { [] }
  let(:verdicts) { { correct: { verdict: 'pass', reason: 'Matches the reference.' } } }
  let(:evaluation) do
    Class.new(RubyLLM::Evaluation) do
      def perform(input)
        input.upcase
      end

      def assertions
        refute_empty output
      end
    end
  end

  before do
    evaluation.evaluator(model:, provider: :openai, protocol: :chat_completions)
    evaluation.evaluation(:correct, 'Agrees with the expected output')
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return do |request|
      requests << JSON.parse(request.body)
      { status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
        model:, choices: [{ index: 0, message: { role: 'assistant', content: JSON.generate(verdicts) },
                            finish_reason: 'stop' }], usage: { prompt_tokens: 100, completion_tokens: 20 }
      }.to_json }
    end
  end

  it 'uses the built-in reviewer with structured output and separated evidence' do
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed
    expect(report.first.evaluations.first.reason).to eq('Matches the reference.')
    expect(requests.first.dig('response_format', 'json_schema', 'schema', 'required')).to eq(['correct'])
    instructions = requests.first['messages'][0...-1].map { |message| message['content'] }.join
    expect(instructions).to include('untrusted data', 'Agrees with the expected output')
    evidence = JSON.parse(requests.first['messages'].last['content'])
    expect(evidence).to include('actual' => 'HELLO', 'expected_output' => 'HELLO')
    expect(evidence).not_to have_key('name')
    expect(report.first.evaluator_cost.total).to be > 0
  end

  it 'accepts an instantiated registry model' do
    evaluation.evaluator(RubyLLM.models.find(model), protocol: :chat_completions)

    expect(evaluation.run(dataset: cases)).to be_passed
  end

  it 'preserves a supplied Agent prompt and uses a fresh conversation for every case' do
    reviewer = Class.new(RubyLLM::Agent) do
      instructions 'You are the policy reviewer.'
    end
    reviewer.model(model, protocol: :chat_completions)
    evaluation.evaluator(reviewer)
    report = evaluation.run(dataset: cases, repetitions: 2)

    expect(report).to be_passed
    expect(requests.map { |request| request['messages'].size }).to eq([3, 3])
    expect(requests.first['messages'].first['content']).to include('You are the policy reviewer.')
    expect(requests.first['messages'].first['content']).not_to include('Accept equivalent')
  end

  it 'records abstentions without counting them as passes or failures' do
    verdicts[:correct][:verdict] = 'unknown'
    report = evaluation.run(dataset: cases)

    expect(report.first.status).to eq(:unassessed)
    expect(report.counts[:unassessed]).to eq(1)
    expect(report.pass_rate).to eq(0)
  end

  it 'does not hide missing, extra, or invalid evaluator answers' do
    [{}, { unexpected: { verdict: 'pass' } }, { correct: { verdict: 'maybe', reason: 'Unclear' } }].each do |answers|
      verdicts.replace(answers)
      report = evaluation.run(dataset: cases)

      expect(report.first.status).to eq(:error)
      expect(report.first.evaluations.first.error).to be_a(StandardError)
    end
  end

  it 'records evaluator request failures and still assesses later cases' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_timeout
    report = evaluation.run(dataset: cases, repetitions: 2)

    expect(report.map(&:status)).to eq(%i[error error])
    expect(report.first.evaluations.first.name).to eq(:correct)
  end

  it 'does not overwrite an Agent output schema' do
    reviewer = Class.new(RubyLLM::Agent) do
      schema do
        string :unrelated
      end
    end
    reviewer.model(model)
    evaluation.evaluator(reviewer)
    report = evaluation.run(dataset: cases)

    expect(report.first.evaluations.first.error.message).to include('schema')
    expect(requests).to be_empty
  end

  it 'keeps evaluator errors distinct from failed application assertions' do
    evaluation.define_method(:assertions) { assert_equal 'WRONG', output }
    verdicts[:correct][:verdict] = 'fail'
    report = evaluation.run(dataset: cases)

    expect(report.first.status).to eq(:failed)
    expect(report.first.assertion_failure).to be_a(Minitest::Assertion)
    expect(report.first.evaluations.first.status).to eq(:failed)
    expect(report.first.error).to be_nil
  end

  context 'with decision models' do
    def judge
      @judge ||= Class.new(RubyLLM::Judge) do
        probability :correct, 'Agrees with the reference'
      end
    end

    before do
      judge.model('jev-latest', provider: :typesafe)
      stub_request(:post, 'https://api.typesafe.ai/v1/systemone').to_return do |request|
        body = JSON.parse(request.body)
        requests << body
        answers = body.fetch('questions').keys.to_h { |name| [name, { type: 'noul', noul: 0.85 }] }
        { status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
          model: 'jev-latest', answers:,
          usage: { input_tokens: 80, output_tokens: 1 }
        }.to_json }
      end
    end

    it 'routes a decision model to native judgments and retains its probability' do
      evaluation.evaluator(RubyLLM.models.find('jev-latest'))
      report = evaluation.run(dataset: cases)

      expect(report.first.evaluations.first.value).to be_a(RubyLLM::Probability)
      expect(report.first.evaluations.first.value.probability).to eq(0.85)
      expect(report.first.status).to eq(:measured)
      expect(report).not_to be_passed
      expect(requests.first['state']).to include('actual' => 'HELLO')
    end

    it 'uses a Judge class questions without repeating their definitions' do
      evaluation = Class.new(self.evaluation)
      evaluation.evaluator(judge)
      evaluation.evaluation(:correct, minimum: 0.8)

      expect(evaluation.run(dataset: cases)).to be_passed
      expect(requests.first.dig('questions', 'correct', 'instructions')).to eq('Agrees with the reference')
    end

    it 'does not treat probabilities below the explicit threshold as passes' do
      evaluation = Class.new(self.evaluation)
      evaluation.evaluator(judge)
      evaluation.evaluation(:correct, minimum: 0.9)

      expect(evaluation.run(dataset: cases).first.status).to eq(:failed)
    end

    it 'rejects conflicting question declarations before making a request' do
      evaluation.evaluator(judge)

      expect { evaluation.run(dataset: cases) }.to raise_error(ArgumentError, /Duplicate Judge question/)
      expect(requests).to be_empty
    end

    it 'supports a separate evaluator for an individual criterion' do
      evaluation.evaluation(:correct_decision, 'Matches reference', evaluator: RubyLLM.models.find('jev-latest'))
      report = evaluation.run(dataset: cases)

      expect(report.first.evaluations.map(&:name)).to eq(%i[correct correct_decision])
      expect(report.first.evaluations.first).to be_passed
      expect(report.first.evaluations.last.status).to eq(:measured)
      expect(requests.size).to eq(2)
    end
  end
end
