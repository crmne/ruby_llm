# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Judge::Question do
  let(:scope) { RubyLLM::Judge.new }

  it 'accepts omitted instructions and structured descriptions for either boolean outcome' do
    question = described_class.new(:urgent, type: :probability,
                                            criteria: { true => { deadline: 'today' }, false => nil })

    expect(question.resolve(scope).criteria).to eq(true => { deadline: 'today' }, false => nil)
    expect(question.resolve(scope).instructions).to be_nil
  end

  it 'preserves arbitrary String option names and nil descriptions' do
    options = { 'Billing & payments' => nil, 'Other team' => ['Everything else'] }
    question = described_class.new('Which team?', type: :choice, criteria: options)

    expect(question.resolve(scope).criteria).to eq('Billing & payments' => nil, 'Other team' => ['Everything else'])
  end

  it 'rejects invalid question definitions' do
    definitions = [
      { type: :probability, instructions: 42 },
      { type: :probability, criteria: { maybe: 'Uncertain' } },
      { type: :probability, criteria: { yes: 'Yes', true => 'Also yes' } },
      { type: :choice, criteria: {} },
      { type: :choice, criteria: { '': 'Blank' } },
      { type: :choice, criteria: { true => 'Boolean option name' } },
      { type: :choice, criteria: { first: 42 } },
      { type: :score, criteria: [] },
      { type: :score, criteria: { first: 'First', second: 'Second' } }
    ]

    definitions.each do |definition|
      expect { described_class.new(:question, **definition).resolve(scope) }.to raise_error(ArgumentError)
    end
  end

  it 'leaves the number of levels and their descriptions to the provider' do
    [['Only level'], ['Calm', nil]].each do |levels|
      expect(described_class.new(:severity, type: :score, criteria: levels).resolve(scope).criteria).to eq(levels)
    end
  end

  it 'rejects conflicting value and block criteria' do
    expect do
      described_class.new(:department, type: :choice, criteria: { billing: nil }) { { other: nil } }
    end.to raise_error(ArgumentError, /criteria or a block/)
  end

  it 'rejects unknown types and misspelled Hash fields' do
    [nil, :text, 42].each do |type|
      expect { described_class.from_h(:question, type:) }.to raise_error(ArgumentError, /Unknown judgment type/)
    end
    expect { described_class.from_h(:question, {}) }.to raise_error(ArgumentError, /Unknown judgment type/)
    expect { described_class.from_h(:question, type: :choice, option: { billing: nil }) }
      .to raise_error(ArgumentError, /Unknown question options: option/)
  end

  it 'supports a proc returning a Hash through the same builder as a declaration block' do
    question = described_class.new(:department, type: :choice, criteria: -> { { billing: ['Payments'] } })

    expect(question.resolve(scope).criteria).to eq(billing: ['Payments'])
  end
end
