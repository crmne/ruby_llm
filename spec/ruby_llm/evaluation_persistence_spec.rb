# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  it 'evaluates application-owned chat records through the existing conversion boundary' do
    record = Chat.create!(model: model_for(:openai))
    record.messages.create!(role: 'user', content: 'Hello')
    record.messages.create!(role: 'assistant', content: 'Welcome', finish_reason: 'stop')
    evaluation = Class.new(described_class) do
      def perform(input)
        Chat.find(input)
      end

      def assertions
        assert_equal 'Welcome', output
        assert_equal %i[user assistant], messages.map(&:role)
      end
    end
    cases = [RubyLLM::Evaluation::Case.new(name: 'persisted', inputs: record.id)]
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed, report.to_h.to_json
    expect(report.first.result).to be_a(Chat)
    expect(report.first.evidence[:messages].size).to eq(2)
  end
end
