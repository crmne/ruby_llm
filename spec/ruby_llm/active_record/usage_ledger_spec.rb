# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::Usage do
  include_context 'with configured RubyLLM'

  let(:owner) { Chat.create!(model: model_for(:anthropic)) }
  let(:audio) { File.expand_path('../../fixtures/ruby.wav', __dir__) }
  let(:transcription_model) { model_for(:gemini, :transcription) }
  let(:embedding_model) { model_for(:openai, :embedding) }
  let(:judgment_model) { model_for(:typesafe, :judgment) }

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def stub_embedding
    body = { model: embedding_model, data: [{ embedding: [0.1, 0.2] }], usage: { prompt_tokens: 3, total_tokens: 3 } }
    stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return(json_response(body))
  end

  def stub_one_shot_operations
    stub_embedding
    stub_request(:post, 'https://api.openai.com/v1/images/generations')
      .to_return(json_response({ data: [{ b64_json: 'aGk=' }], usage: { input_tokens: 5, output_tokens: 7 } }))
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{transcription_model}:generateContent")
      .to_return(json_response({ candidates: [{ content: { parts: [{ text: 'Ruby' }] }, finishReason: 'STOP' }],
                                 usageMetadata: { promptTokenCount: 40, candidatesTokenCount: 2 } }))
    stub_request(:post, 'https://api.typesafe.ai/v1/systemone')
      .to_return(json_response({ model: judgment_model, answers: { urgent: { type: 'noul', noul: 0.9 } },
                                 usage: { input_tokens: 11, output_tokens: 1 } }))
  end

  def embed(**)
    RubyLLM.embed('Ruby', model: embedding_model, provider: :openai, **)
  end

  def rows_for(record)
    described_class.where(owner: record).order(:id)
  end

  it 'writes a row for each one-shot operation, attributed to its owner and to no chat' do
    stub_one_shot_operations

    embed(owner:)
    RubyLLM.paint('A paper boat', model: model_for(:openai, :image), provider: :openai, owner:)
    RubyLLM.transcribe(audio, model: transcription_model, provider: :gemini, owner:)
    RubyLLM.judge('Help', model: judgment_model, provider: :typesafe, assume_model_exists: true, owner:,
                          questions: { urgent: { type: :probability, instructions: 'Is this urgent?' } })

    rows = rows_for(owner)
    expect(rows.map(&:operation)).to eq(%w[embedding image transcription judgment])
    expect(rows.map(&:status)).to all(eq('succeeded'))
    expect(rows.map(&:chat_id)).to all(be_nil)
    expect(rows.map { |row| [row.input_tokens, row.output_tokens] }).to eq([[3, nil], [5, 7], [40, 2], [11, 1]])
    expect(rows.first).to have_attributes(provider: 'openai', model: embedding_model, owner:)
  end

  it 'attributes rows to the ambient owner, lets the keyword win, and writes unattributed rows' do
    stub_embedding
    other = Chat.create!(model: model_for(:anthropic))

    expect do
      RubyLLM.with_usage_owner(owner) do
        embed
        embed(owner: other)
      end
      embed
    end.to change(described_class, :count).by(3)

    expect(rows_for(owner).count).to eq(1)
    expect(rows_for(other).count).to eq(1)
    expect(described_class.last).to have_attributes(owner_type: nil, owner_id: nil, chat_id: nil)
  end

  it 'records an attempt that failed after the provider may have billed it' do
    stub_request(:post, 'https://api.openai.com/v1/embeddings')
      .to_return(json_response({ error: { message: 'Boom' } }, status: 500))

    expect { embed(owner:) }.to raise_error(RubyLLM::ServerError)

    expect(rows_for(owner).map(&:status)).to eq(['failed'])
  end

  it 'records a blocked transcription with the tokens the provider billed' do
    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/#{transcription_model}:generateContent")
      .to_return(json_response({ promptFeedback: { blockReason: 'SAFETY' },
                                 usageMetadata: { promptTokenCount: 133, totalTokenCount: 133 } }))

    expect { RubyLLM.transcribe(audio, model: transcription_model, provider: :gemini, owner:) }
      .to raise_error(RubyLLM::ContentFilterError)

    expect(rows_for(owner).sole).to have_attributes(operation: 'transcription', status: 'failed', chat_id: nil,
                                                    input_tokens: 133)
  end

  it 'leaves the rows of a persisted chat to the chat, written once' do
    reply = { id: 'msg_1', type: 'message', role: 'assistant', model: model_for(:anthropic),
              content: [{ type: 'text', text: 'Hi' }], stop_reason: 'end_turn',
              usage: { input_tokens: 9, output_tokens: 2 } }
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return(json_response(reply))
    chat = Chat.create!(model: model_for(:anthropic))

    expect { RubyLLM.with_usage_owner(owner) { chat.ask('Hello') } }.to change(described_class, :count).by(1)

    expect(chat.ruby_llm_usages.sole).to have_attributes(operation: 'chat', owner_id: nil, input_tokens: 9)
  end

  it 'attributes the rows of a chat without a record to the owner' do
    reply = { id: 'msg_1', type: 'message', role: 'assistant', model: model_for(:anthropic),
              content: [{ type: 'text', text: 'Hi' }], stop_reason: 'end_turn',
              usage: { input_tokens: 9, output_tokens: 2 } }
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return(json_response(reply))

    RubyLLM.with_usage_owner(owner) { RubyLLM.chat(model: model_for(:anthropic)).ask('Hello') }

    expect(rows_for(owner).sole).to have_attributes(operation: 'chat', chat_id: nil, output_tokens: 2)
  end

  it 'logs a failed write and returns the result of the operation' do
    stub_embedding
    allow(described_class).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'disk full')
    allow(RubyLLM.logger).to receive(:warn)

    expect(embed(owner:).vectors).to eq([0.1, 0.2])
    expect(RubyLLM.logger).to have_received(:warn).with(/could not record embedding usage.*disk full/)
  end

  it 'keeps the caller transaction usable when a write fails' do
    stub_embedding
    allow(described_class).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, 'constraint failed')
    allow(RubyLLM.logger).to receive(:warn)

    Chat.transaction do
      embed(owner:)
      Chat.create!(model: model_for(:anthropic))
    end

    expect(rows_for(owner)).to be_empty
  end

  it 'skips attempts without a model, which the ledger cannot store' do
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :moderation, provider: :bedrock, model: nil,
                                                  status: :succeeded, owner:)

    expect { described_class.record(entry) }.not_to change(described_class, :count)
  end
end
