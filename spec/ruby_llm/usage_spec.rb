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

  it 'keeps tokens unknown for attempts that may have been billed' do
    tracker = build_tracker
    entry = tracker.start

    tracker.fail_attempt(entry, Faraday::TimeoutError.new('execution expired'))

    expect(entry.status).to eq(:failed)
    expect(entry.tokens.to_h).to be_empty
    expect(entry).not_to be_usage_available
  end

  it 'keeps stream tokens observed before a never-sent classification' do
    tracker = build_tracker
    entry = tracker.start
    tracker.observe(RubyLLM::Chunk.new(role: :assistant, content: 'partial', input_tokens: 7))

    tracker.fail_attempt(entry, Faraday::ConnectionFailed.new('reset'))

    expect(entry.tokens.to_h).to eq(input_tokens: 7)
  end
end
