# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:model) { model_for(:gemini) }
  let(:chat) { Chat.create!(model:, provider: :gemini) }

  def body(text, reason:, token: nil)
    candidate = { content: { role: 'model', parts: [{ text: }] }, finishReason: reason }
    candidate[:continuationToken] = token if token
    { candidates: [candidate], modelVersion: model,
      usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 2 } }
  end

  [false, true].each do |streaming|
    it "persists one assembled answer and both usage rows with streaming #{streaming}" do
      replies = [body('One ', reason: 'CONTINUATION', token: 'next'), body('two', reason: 'STOP')]
      action = streaming ? 'streamGenerateContent?alt=sse' : 'generateContent'
      responses = replies.map do |reply|
        { body: streaming ? "data: #{JSON.generate(reply)}\n\n" : JSON.generate(reply),
          headers: { 'Content-Type' => streaming ? 'text/event-stream' : 'application/json' } }
      end
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:#{action}")
        .to_return(*responses)
      chat.with_max_output_tokens(262_144)

      reply = streaming ? chat.ask('Think') { |_chunk| nil } : chat.ask('Think')

      expect(reply.content).to eq('One two')
      expect(chat.messages.order(:id).pluck(:role)).to eq(%w[user assistant])
      record = chat.messages.where(role: 'assistant').sole
      expect(record.reload.content).to eq('One two')
      expect(record.tokens.input).to eq(20)
      expect(record.tokens.output).to eq(4)
      expect(record.ruby_llm_usages.count).to eq(2)
      expect(record.to_llm.cost.total).to eq(reply.cost.total)
    end
  end
end
