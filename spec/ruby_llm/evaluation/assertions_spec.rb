# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation::Assertions do
  include_context 'with configured RubyLLM'

  let(:cases) { [RubyLLM::Evaluation::Case.new(name: 'greeting', inputs: 'hello')] }

  def evaluation(&assertions)
    Class.new(RubyLLM::Evaluation) do
      evaluator false

      def perform(input)
        input.upcase
      end

      define_method(:assertions, &assertions) if assertions
    end
  end

  it 'does not load Minitest when an evaluation has no assertions' do
    allow(described_class).to receive(:new).and_call_original

    report = evaluation.run(dataset: cases)

    expect(described_class).not_to have_received(:new)
    expect(report.first.assertion_count).to eq(0)
  end

  it 'explains how to install Minitest when assertions run without it' do
    allow(described_class).to receive(:available?).and_return(false)

    expect { evaluation { assert true }.run(dataset: cases) }
      .to raise_error(LoadError, /require the 'minitest' gem/)
  end

  it 'answers respond_to? for Minitest assertions only' do
    instance = evaluation.new

    expect(instance).to respond_to(:assert_equal)
    expect(instance).not_to respond_to(:assert_nonexistent)
  end

  it 'matches only Minitest assertion failures' do
    require 'minitest'

    expect(described_class::Failure === Minitest::Assertion.new).to be(true) # rubocop:disable Style/CaseEquality
    expect(described_class::Failure === StandardError.new).to be(false) # rubocop:disable Style/CaseEquality
  end
end
