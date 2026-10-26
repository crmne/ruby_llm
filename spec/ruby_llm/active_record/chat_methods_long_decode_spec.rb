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

    it "resumes an unfinished answer in a new process with streaming #{streaming}" do
      action = streaming ? 'streamGenerateContent?alt=sse' : 'generateContent'
      encode = lambda do |reply|
        { body: streaming ? "data: #{JSON.generate(reply)}\n\n" : JSON.generate(reply),
          headers: { 'Content-Type' => streaming ? 'text/event-stream' : 'application/json' } }
      end
      requests = []
      stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:#{action}")
        .to_return(encode.call(body('One ', reason: 'CONTINUATION', token: 'next')))
        .then.to_return(status: 503, body: '{}')
        .then.to_return do |request|
          requests << JSON.parse(request.body)
          encode.call(body('two', reason: 'STOP'))
        end
      chat.with_max_output_tokens(262_144)

      expect { streaming ? chat.ask('Think') { |_chunk| nil } : chat.ask('Think') }
        .to raise_error(RubyLLM::ServiceUnavailableError)

      unfinished = chat.messages.where(role: 'assistant').sole
      expect(unfinished.content).to eq('One ')
      expect(unfinished.continuation).to eq('next')
      expect(unfinished.ruby_llm_usages.count).to eq(1)

      restarted = Chat.find(chat.id).with_max_output_tokens(262_144)
      expect(restarted).not_to be_complete
      reply = streaming ? restarted.complete { |_chunk| nil } : restarted.complete

      expect(reply.content).to eq('One two')
      expect(requests.sole['continuationToken']).to eq('next')
      expect(requests.sole['contents'].size).to eq(1)
      record = restarted.messages.where(role: 'assistant').sole
      expect(record.id).to eq(unfinished.id)
      expect(record.content).to eq('One two')
      expect(record.continuation).to be_nil
      expect(record).to be_stopped
      expect(record.ruby_llm_usages.count).to eq(2)
      expect(restarted).to be_complete
    end
  end

  it 'leaves no truncated answer behind when the messages table has no continuation column' do
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
      .to_return_json(body: body('One ', reason: 'CONTINUATION', token: 'next'))
      .then.to_return(status: 503, body: '{}')
    connection = ActiveRecord::Base.connection

    ActiveRecord::Base.transaction do
      connection.remove_column(:messages, :continuation)
      Message.reset_column_information

      expect { chat.with_max_output_tokens(262_144).ask('Think') }.to raise_error(RubyLLM::ServiceUnavailableError)
      expect(chat.messages.reload.pluck(:role)).to eq(%w[user])
      raise ActiveRecord::Rollback
    end
  ensure
    Message.reset_column_information
  end

  it 'keeps an unfinished answer that has only thought so far' do
    thought = body(nil, reason: 'CONTINUATION', token: 'next')
    thought[:candidates][0][:content][:parts] = [{ text: 'Planning', thought: true }]
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
      .to_return_json(body: thought).then.to_return(status: 503, body: '{}')

    expect { chat.with_max_output_tokens(262_144).ask('Think') }.to raise_error(RubyLLM::ServiceUnavailableError)

    record = chat.messages.where(role: 'assistant').sole
    expect(record.content).to be_blank
    expect(record.thinking_text).to eq('Planning')
    expect(record.continuation).to eq('next')
  end
end
