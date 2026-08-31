# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RubyLLM::Usage::Tracker' do
  include_context 'with configured RubyLLM'

  let(:provider) { instance_double(RubyLLM::Providers::OpenAI, slug: :openai) }
  let(:model) { RubyLLM::Model.new(id: 'test-model', name: 'Test Model', provider: 'openai') }

  def build_tracker
    RubyLLM.const_get(:Usage)::Tracker.new(
      operation: :chat,
      provider: provider,
      model: model,
      config: RubyLLM.config
    )
  end

  it 'records zero tokens for attempts that never reached the provider' do
    tracker = build_tracker
    entry = tracker.start

    tracker.fail_attempt(entry, Faraday::ConnectionFailed.new('connection refused'))

    expect(entry.status).to eq(:failed)
    expect(entry.tokens.to_h).to eq(input_tokens: 0, output_tokens: 0)
    expect(entry).to be_usage_available
  end

  it 'records zero tokens for attempts the provider refused' do
    tracker = build_tracker
    entry = tracker.start
    response = Struct.new(:status, :body).new(429, '')

    tracker.fail_attempt(entry, RubyLLM::RateLimitError.new('rate limit exceeded', response: response))

    expect(entry.status).to eq(:failed)
    expect(entry.tokens.to_h).to eq(input_tokens: 0, output_tokens: 0)
    expect(entry).to be_usage_available
  end

  it 'prices a call whose first attempt was rate limited' do
    tracker = RubyLLM.const_get(:Usage)::Tracker.new(
      operation: :chat,
      provider: provider,
      model: RubyLLM.models.find('gpt-4.1-nano'),
      config: RubyLLM.config
    )
    refused = tracker.start
    response = Struct.new(:status, :body).new(429, '')
    tracker.fail_attempt(refused, RubyLLM::RateLimitError.new('rate limit exceeded', response: response))
    tracker.start
    result = RubyLLM::Message.new(role: :assistant, content: 'hi', model: 'gpt-4.1-nano',
                                  input_tokens: 10, output_tokens: 4)

    tracker.succeed(result)

    expect(result.cost.total).to be_positive
  end

  it 'keeps tokens unknown for attempts that may have been billed' do
    tracker = build_tracker
    entry = tracker.start

    tracker.fail_attempt(entry, Faraday::TimeoutError.new('execution expired'))

    expect(entry.status).to eq(:failed)
    expect(entry.tokens.to_h).to be_empty
    expect(entry).not_to be_usage_available
  end

  it 'recognizes an exact cost even when token counts are unavailable' do
    entry = RubyLLM.const_get(:Usage)::Entry.new(
      operation: :chat,
      provider: 'openrouter',
      model: 'test-model',
      cost: RubyLLM::Cost.from_h({ total: 0.0042 })
    )
    message = RubyLLM::Message.new(role: :assistant, content: 'hi', usage_entries: [entry])
    chat = RubyLLM.chat(model: 'gpt-4.1-nano')
    chat.usage_entries = [entry]

    expect(entry).to be_cost_available
    expect(entry).not_to be_usage_available
    expect(message.cost.total).to eq(0.0042)
    expect(chat.cost.total).to eq(0.0042)
  end

  it 'keeps aggregate cost unknown when any potentially billed attempt is unknown' do
    known = RubyLLM.const_get(:Usage)::Entry.new(
      operation: :chat,
      provider: 'openrouter',
      model: 'test-model',
      cost: RubyLLM::Cost.from_h({ total: 0.0042 })
    )
    unknown = RubyLLM.const_get(:Usage)::Entry.new(
      operation: :chat,
      provider: 'openrouter',
      model: 'test-model',
      status: :failed
    )
    chat = RubyLLM.chat(model: 'gpt-4.1-nano')
    chat.usage_entries = [known, unknown]

    expect(chat.cost.total).to be_nil
  end

  it 'keeps stream tokens observed before a never-sent classification' do
    tracker = build_tracker
    entry = tracker.start
    tracker.observe(RubyLLM::Chunk.new(role: :assistant, content: 'partial', input_tokens: 7))

    tracker.fail_attempt(entry, Faraday::ConnectionFailed.new('reset'))

    expect(entry.tokens.to_h).to eq(input_tokens: 7)
  end

  it 'refuses an unknown operation or status' do
    expect do
      RubyLLM.const_get(:Usage)::Entry.new(operation: :telepathy, provider: 'openai', model: 'm')
    end.to raise_error(ArgumentError, 'Unknown usage operation: :telepathy')

    expect do
      RubyLLM.const_get(:Usage)::Entry.new(operation: :chat, provider: 'openai', model: 'm', status: :maybe)
    end.to raise_error(ArgumentError, 'Unknown usage status: :maybe')
  end

  it 'summarizes an entry for inspection' do
    entry = RubyLLM.const_get(:Usage)::Entry.new(operation: :chat, provider: 'openai', model: 'gpt-4.1-nano')

    expect(entry.inspect).to include('chat', 'openai', 'gpt-4.1-nano', 'pending')
    expect(entry.to_h).to include(operation: :chat, provider: 'openai', model: 'gpt-4.1-nano', status: :pending)
  end

  it 'records a cancelled attempt as cancelled' do
    tracker = build_tracker
    entry = tracker.start

    tracker.fail_attempt(entry, RubyLLM::CancelledError.new('stopped'))

    expect(entry).to be_cancelled
  end

  it 'ignores a second failure for an attempt that already finished' do
    tracker = build_tracker
    entry = tracker.start
    tracker.fail_attempt(entry, Faraday::ConnectionFailed.new('reset'))

    expect { tracker.fail_attempt(entry, Faraday::TimeoutError.new('late')) }.not_to change(entry, :status)
    expect { tracker.fail_attempt(nil, Faraday::TimeoutError.new('late')) }.not_to raise_error
  end

  it 'fails every attempt still in flight' do
    tracker = build_tracker
    first = tracker.start
    second = tracker.start

    tracker.fail_pending(Faraday::ConnectionFailed.new('reset'))

    expect([first, second]).to all(be_failed)
  end

  it 'ignores a chunk when nothing is in flight' do
    tracker = build_tracker

    expect { tracker.observe(RubyLLM::Chunk.new(role: :assistant, content: 'x')) }.not_to raise_error
  end

  it 'ignores an observation that carries no tokens' do
    tracker = build_tracker
    entry = tracker.start

    tracker.observe(Object.new)

    expect(entry.tokens.to_h).to be_empty
  end

  it 'attaches the ledger to a result even when no attempt was recorded' do
    tracker = build_tracker
    result = RubyLLM::Message.new(role: :assistant, content: 'hi')

    expect(tracker.succeed(result)).to equal(result)
    expect(result.ruby_llm_usage_entries).to be_empty
  end

  it 'credits only the last attempt with the tokens the call used' do
    tracker = build_tracker
    retried = tracker.start
    final = tracker.start
    result = RubyLLM::Message.new(role: :assistant, content: 'hi', input_tokens: 10, output_tokens: 4)

    tracker.succeed(result)

    expect(retried.tokens.to_h).to be_empty
    expect(final.tokens.input).to eq(10)
    expect(result.ruby_llm_usage_entries).to eq([retried, final])
  end
end
