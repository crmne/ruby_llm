# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation::Result do
  it 'preserves boolean verdicts without turning a failure into an error' do
    expect(described_class.new(name: :correct, value: true)).to be_passed
    expect(described_class.new(name: :correct, value: false).status).to eq(:failed)
    expect(described_class.new(name: :correct, value: nil).status).to eq(:unassessed)
  end

  it 'requires an explicit policy before counting probabilities as passes' do
    probability = RubyLLM::Probability.new(probability: 0.8)
    measurement = described_class.new(name: :correct, value: probability)

    expect(measurement.status).to eq(:measured)
    expect(measurement).not_to be_passed
    expect(described_class.new(name: :correct, value: probability, minimum: 0.8)).to be_passed
    expect(described_class.new(name: :correct, value: probability, minimum: 0.9).status).to eq(:failed)
  end

  it 'preserves score distributions and their native scale' do
    score = RubyLLM::Score.new(score: 1.2, levels: %w[Bad Fair Good], probabilities: { 0 => 0.1, 1 => 0.6, 2 => 0.3 },
                               confidence: 0.5)
    result = described_class.new(name: :quality, value: score, minimum: 1)

    expect(result).to be_passed
    expect(result.to_h[:value][:probabilities]).to eq(0 => 0.1, 1 => 0.6, 2 => 0.3)
    expect(result.to_h[:value][:score]).to eq(1.2)
  end

  it 'does not reinterpret a choice confidence as quality' do
    choice = RubyLLM::Choice.new(choice: :wrong, probabilities: { wrong: 1.0, right: 0.0 }, confidence: 1.0)
    result = described_class.new(name: :correct, value: choice)

    expect(result.status).to eq(:measured)
    expect { described_class.new(name: :correct, value: choice, minimum: 0.8) }.to raise_error(ArgumentError, /Minimum/)
  end

  it 'serializes errors distinctly from verdicts and missing evidence' do
    result = described_class.new(name: :correct, error: RubyLLM::Error.new('Evaluator unavailable'))

    expect(result.status).to eq(:error)
    expect(result.to_h[:error]).to eq(class: 'RubyLLM::Error', message: 'Evaluator unavailable')
    expect(result).not_to be_passed
  end
end
