# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  it 'evaluates application-owned chat records through the existing conversion boundary' do
    record = Chat.create!(model: model_for(:openai))
    record.messages.create!(role: 'user', content: 'Hello')
    record.messages.create!(role: 'assistant', content: 'Welcome', finish_reason: 'stop')
    evaluation = Class.new(described_class) do
      evaluator false

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

  [false, true].each do |persisted|
    it "records task and native evaluator attempts once, with a persisted chat: #{persisted}" do
      task_model = model_for(:anthropic)
      judgment_model = model_for(:typesafe, :judgment)
      owner = Chat.create!(model: task_model)
      chat = persisted ? Chat.create!(model: task_model) : RubyLLM.chat(model: task_model)
      reply = { id: 'msg_1', type: 'message', role: 'assistant', model: task_model,
                content: [{ type: 'text', text: 'Hello' }], stop_reason: 'end_turn',
                usage: { input_tokens: 9, output_tokens: 2 } }
      judgment = { model: judgment_model, answers: { correct: { type: 'noul', noul: 0.9 } },
                   usage: { input_tokens: 11, output_tokens: 1 } }
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: reply.to_json)
      stub_request(:post, 'https://api.typesafe.ai/v1/systemone')
        .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: judgment.to_json)
      evaluation = Class.new(described_class)
      evaluation.evaluator(model: judgment_model, provider: :typesafe)
      evaluation.evaluation(:correct, 'The output greets the user', minimum: 0.8)
      evaluation.define_method(:perform) { |input| chat.ask(input).content }
      dataset = [RubyLLM::Evaluation::Case.new(name: 'greeting', inputs: 'Hi')]
      report = nil

      expect do
        report = RubyLLM.with_usage_owner(owner) { evaluation.run(dataset:) }
      end.to change(RubyLLM::ActiveRecord::Usage, :count).by(2)

      rows = RubyLLM::ActiveRecord::Usage.order(:id).last(2)
      expect(report).to be_passed
      expect(rows.map(&:operation)).to eq(%w[chat judgment])
      expect(rows.last).to have_attributes(owner:, chat_id: nil)
      expect(rows.first).to have_attributes(chat_id: persisted ? chat.id : nil, owner_id: persisted ? nil : owner.id)
      expect(report.tokens.to_h).to eq(input_tokens: 20, output_tokens: 3)
      expect(report.tokens.to_h).to eq(RubyLLM::Tokens.aggregate(rows.map(&:tokens)).to_h)
      expect(report.first.task_cost.total).to be_within(1e-10).of(rows.first.cost.total)
      expect(report.first.evaluator_cost.to_h).to eq(rows.last.cost.to_h)
      expect(report.cost.total).to be_nil
    end
  end
end
