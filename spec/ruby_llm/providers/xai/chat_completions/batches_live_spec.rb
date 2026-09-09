# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::ChatCompletions::Batches, :live do
  it 'collects completed structured Responses and Chat Completions results in submission order' do
    model = model_for(:xai, :server_tools)
    schema = { type: 'object', properties: { language: { type: 'string' } }, required: ['language'],
               additionalProperties: false }
    structured = RubyLLM.chat(model:, provider: :xai).with_schema(schema).with_max_output_tokens(256)
                        .ask_later('Return language Ruby.')
    plain = RubyLLM.chat(model:, provider: :xai, protocol: :chat_completions).with_max_output_tokens(256)
                   .ask_later('Reply with exactly one word: Rails')
    batch = RubyLLM.batch([structured, plain])
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120
    sleep 5 until batch.refresh.complete? || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    expect(batch).to be_complete
    expect(batch.results.map(&:content)).to all(be_a(String))
    expect(batch.results.first.parsed).to eq('language' => 'Ruby')
    expect(batch.results.last.content).to include('Rails')
    expect(batch.results).to all(be_a(RubyLLM::Message))
    expect(batch.results.first.tokens.input).to be_positive
    expect(batch.results.first.tokens.reported_cost).to be >= 0
  ensure
    batch&.cancel unless batch&.complete?
  end
end
